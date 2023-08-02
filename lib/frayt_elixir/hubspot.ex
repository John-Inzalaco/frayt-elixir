defmodule FraytElixir.Hubspot do
  require Logger
  alias FraytElixir.ExHubspot
  alias FraytElixir.Hubspot.Account
  alias FraytElixir.Accounts
  alias Accounts.{Shipper, Company, Location, AdminUser, User}
  alias FraytElixir.Repo
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Shipment
  alias Shipment.Match
  import Ecto.Query
  import FraytElixir.Guards

  def setup_account(code) do
    with {:ok,
          %{
            "refresh_token" => refresh_token,
            "access_token" => access_token,
            "expires_in" => expires_in
          }} <- ExHubspot.create_tokens(code),
         {:ok,
          %{
            "hub_domain" => hub_domain,
            "hub_id" => hub_id
          }} <-
           ExHubspot.get_refresh_token_data(refresh_token) do
      account = get_account_by_hubspot_id(hub_id) || %Account{}

      account
      |> change_account(%{
        hubspot_id: hub_id,
        domain: hub_domain,
        refresh_token: refresh_token,
        access_token: access_token,
        expires_at: get_expires_at(expires_in)
      })
    else
      {:error, _code, error} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_account_tokens(%Account{refresh_token: refresh_token} = account) do
    case ExHubspot.refresh_tokens(refresh_token) do
      {:ok,
       %{
         "refresh_token" => refresh_token,
         "access_token" => access_token,
         "expires_in" => expires_in
       }} ->
        change_account(account, %{
          refresh_token: refresh_token,
          access_token: access_token,
          expires_at: get_expires_at(expires_in)
        })

      {:error, _code, error} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
  end

  def get_default_account,
    do:
      Account
      |> first()
      |> Repo.one()

  def get_access_token(%Account{expires_at: expires_at, access_token: access_token} = account) do
    # Allow 30 seconds for reaching hubspot server
    current_time = DateTime.utc_now() |> DateTime.add(30)

    case DateTime.compare(expires_at, current_time) do
      :gt ->
        {:ok, access_token}

      _ ->
        with {:ok, %Account{access_token: access_token}} <- update_account_tokens(account) do
          {:ok, access_token}
        end
    end
  end

  def get_access_token(_), do: {:error, :invalid_account}

  def sync_shipper(shipper, attrs) do
    with {:ok, %{"id" => contact_id}} <- find_or_create_contact_from_shipper(attrs),
         {:ok, owner_id} <- get_contact_owner_id(contact_id) do
      sales_rep_id =
        case get_sales_rep_id_by_hubspot_id(owner_id) do
          {:ok, sales_rep_id} -> sales_rep_id
          _ -> nil
        end

      shipper
      |> Shipper.hubspot_changeset(%{hubspot_id: contact_id, sales_rep_id: sales_rep_id})
      |> Repo.update()
    else
      {:ok, _} -> {:error, :not_found}
      {:error, error} -> {:error, error}
      {:error, _code, error} -> {:error, error}
    end
  end

  def create_contact_from_shipper(attrs) do
    with {:ok, %{"id" => company_id}} <- create_company(attrs),
         {:ok, %{"id" => contact_id} = contact} <- create_contact(attrs),
         {:ok, _} <- ExHubspot.add_contact_to_company(company_id, contact_id) do
      {:ok, contact}
    end
  end

  def find_or_create_contact_from_shipper(%{email: email} = attrs) do
    case get_contact_by_email(email) do
      {:ok, nil} ->
        create_contact_from_shipper(attrs)

      {:ok, contact} ->
        {:ok, contact}

      {:error, _code, error} ->
        {:error, error}
    end
  end

  def create_company(attrs),
    do:
      attrs
      |> Map.take([
        :city,
        :state,
        :monthly_shipments,
        :start_shipping,
        :phone,
        :api_integration,
        :schedule_demo
      ])
      |> Map.put(:name, Map.get(attrs, :company))
      |> Map.put(
        :numberofemployees,
        (Map.get(attrs, :team_size) || "") |> String.replace(~r/^\d+-/, "")
      )
      |> ExHubspot.create_company()

  def create_contact(attrs),
    do:
      attrs
      |> Map.take([:city, :state, :email, :phone, :referrer])
      |> Map.put(:firstname, Map.get(attrs, :first_name))
      |> Map.put(:lastname, Map.get(attrs, :last_name))
      |> Map.put(:hs_lead_status, "REACTIVATE")
      |> ExHubspot.create_contact()

  def update_last_match(%Match{shortcode: shortcode} = match, mst) do
    case get_match_contact_id(match) do
      {:ok, contact_id} ->
        attrs = %{last_match: mst.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")}

        case ExHubspot.update_contact(contact_id, attrs) do
          {:ok, _} ->
            :ok

          {:error, _code, error} ->
            Logger.error("Failed to update last match for #{shortcode}: #{inspect(error)}")
            :error

          {:error, error} ->
            Logger.error("Failed to update last match for #{shortcode}: #{inspect(error)}")
            :error
        end

      _ ->
        :error
    end
  end

  def sync_sales_rep(company_hubspot_id, owner_id) do
    with {:error, message} <- update_sales_rep_for_company(company_hubspot_id, owner_id) do
      Logger.error(message)
      {:error, message}
    end
  rescue
    HTTPoison.Error ->
      message =
        "Failed to assign sales rep for Hubspot company #{company_hubspot_id}. Request timed out. Please try again in a couple minutes."

      # Slack.send_message(:sales, message)
      Logger.error(message)
      {:error, message}
  end

  defp update_sales_rep_for_company(company_hubspot_id, owner_id) do
    case ExHubspot.get_company(company_hubspot_id, associations: [:contacts]) do
      {:ok, %{"properties" => %{"name" => company_name}} = data} ->
        with {:ok, contact_hubspot_id} <- fetch_company_contact_id(data),
             {:ok, %_{} = record} <- update_sales_rep_for_contact_id(contact_hubspot_id, owner_id) do
          {:ok, record}
        else
          error ->
            {:error, "Failed to assign sales rep to #{company_name}. " <> error_to_message(error)}
        end

      error ->
        message =
          "Failed to assign sales rep for Hubspot company #{company_hubspot_id}. Unable to fetch company data from Hubspot. " <>
            inspect(error)

        {:error, message}
    end
  end

  defp update_sales_rep_for_contact_id(contact_hubspot_id, owner_id) do
    with {:ok, %Shipper{} = shipper} <- get_shipper_by_contact_id(contact_hubspot_id) do
      case get_sales_rep_id_by_hubspot_id(owner_id) do
        {:ok, sales_rep_id} ->
          set_shipper_or_company_sales_rep(shipper, sales_rep_id)

        {:error, :email_not_found, email} ->
          {:error, "Unable to find sales rep with email #{email}"}

        {:error, :not_found, id} ->
          {:error, "Unable to find Hubspot owner #{id}"}
      end
    end
  end

  defp fetch_company_contact_id(company_data) do
    case company_data do
      %{
        "associations" => %{
          "contacts" => %{"results" => [%{"id" => contact_hubspot_id} | _]}
        }
      } ->
        {:ok, contact_hubspot_id}

      _ ->
        {:error, "No contacts associated with company"}
    end
  end

  defp get_shipper_by_contact_id(contact_hubspot_id) do
    with {:ok, %{"properties" => %{"email" => shipper_email}}} <-
           ExHubspot.get_contact(contact_hubspot_id) do
      case Accounts.get_shipper_by_email(shipper_email) do
        %Shipper{} = shipper -> {:ok, shipper}
        nil -> {:error, "Unable to find shipper with email #{shipper_email}"}
      end
    end
  end

  defp set_shipper_or_company_sales_rep(shipper, sales_rep_id) do
    case Repo.preload(shipper, [:user, location: :company]) do
      %Shipper{location: %Location{company: %Company{} = company}} ->
        Accounts.update_company(company, %{sales_rep_id: sales_rep_id})

      %Shipper{} = shipper ->
        Accounts.update_shipper(shipper, %{sales_rep_id: sales_rep_id})
    end
  end

  defp error_to_message({:error, message}) when is_binary(message), do: message

  defp error_to_message({:error, %Ecto.Changeset{} = changeset}),
    do: DisplayFunctions.humanize_errors(changeset)

  defp error_to_message(error) do
    Logger.error("Update sales rep Error: #{inspect(error)}")
    "Unknown error"
  end

  def get_sales_rep_id_by_hubspot_id(hub_id) when is_empty(hub_id), do: {:ok, nil}

  def get_sales_rep_id_by_hubspot_id(hub_id) do
    case ExHubspot.get_owner(hub_id) do
      {:ok, %{"email" => sales_rep_email}} ->
        case Accounts.get_admin_by_email(sales_rep_email) do
          %AdminUser{id: sales_rep_id} -> {:ok, sales_rep_id}
          nil -> {:error, :email_not_found, sales_rep_email}
        end

      _ ->
        {:error, :not_found, hub_id}
    end
  end

  defp get_contact_owner_id(contact_id) do
    case ExHubspot.get_contact(contact_id,
           properties: [:hubspot_owner_id],
           associations: [:companies]
         ) do
      {:ok, %{"properties" => %{"hubspot_owner_id" => owner_id}}} when not is_nil(owner_id) ->
        {:ok, owner_id}

      {:ok,
       %{
         "associations" => %{
           "companies" => %{"results" => [%{"id" => company_id} | _]}
         }
       }} ->
        with {:ok, %{"properties" => %{"hubspot_owner_id" => owner_id}}} <-
               ExHubspot.get_company(company_id, properties: [:hubspot_owner_id]) do
          {:ok, owner_id}
        end

      {:ok, _} ->
        {:ok, nil}

      {:error, _code, error} ->
        {:error, error}
    end
  end

  defp get_match_contact_id(%Match{shipper: %Ecto.Association.NotLoaded{}} = match),
    do: match |> Repo.preload(shipper: [:user]) |> get_match_contact_id()

  defp get_match_contact_id(%Match{shipper: %Shipper{hubspot_id: contact_id}})
       when not is_nil(contact_id),
       do: {:ok, contact_id}

  defp get_match_contact_id(
         %Match{shipper: %Shipper{user: %Ecto.Association.NotLoaded{}}} = match
       ),
       do: match |> Repo.preload(shipper: [:user]) |> get_match_contact_id()

  defp get_match_contact_id(%Match{shipper: %Shipper{user: %User{email: email}}}) do
    case get_contact_by_email(email) do
      {:ok, %{"id" => contact_id}} -> {:ok, contact_id}
      _ -> {:error, :not_found}
    end
  end

  defp get_match_contact_id(_), do: {:error, :not_found}

  defp get_contact_by_email(email) do
    case ExHubspot.find_contact([{:email, :eq, email}]) do
      {:ok, %{"results" => [contact | _]}} -> {:ok, contact}
      {:ok, _} -> {:ok, nil}
      err -> err
    end
  end

  defp get_account_by_hubspot_id(hub_id) do
    Repo.get_by(Account, hubspot_id: hub_id)
  end

  defp change_account(account, attrs),
    do:
      account
      |> Account.changeset(attrs)
      |> Repo.insert_or_update()

  defp get_expires_at(expires_in),
    do: DateTime.utc_now() |> DateTime.add(expires_in - 60, :second)
end
