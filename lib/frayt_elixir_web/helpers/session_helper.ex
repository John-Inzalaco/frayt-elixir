defmodule FraytElixirWeb.SessionHelper do
  use FraytElixirWeb, :controller

  alias FraytElixir.Repo
  alias FraytElixirWeb.FallbackController
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.{ApiAccount, Company, Shipper, Location, User, AdminUser}
  alias FraytElixirWeb.Plugs.Auth

  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.DriverDocuments

  def user_has_role(%User{admin: %Ecto.Association.NotLoaded{}} = user, role),
    do: user |> Repo.preload(:admin) |> user_has_role(role)

  def user_has_role(%User{admin: admin}, role), do: user_has_role(admin, role)

  def user_has_role(admin, roles) when is_list(roles),
    do: Enum.any?(roles, &user_has_role(admin, &1))

  def user_has_role(%AdminUser{role: user_role}, role), do: user_role == role
  def user_has_role(_user, _role), do: false

  def get_current_user(conn), do: Auth.current_user(conn)

  def get_current_shipper(conn) do
    case get_current_user(conn) do
      %User{} = user ->
        user
        |> Ecto.assoc(:shipper)
        |> Repo.one()
        |> Repo.preload([:user, :address, location: [company: :locations]])

      _ ->
        nil
    end
  end

  def get_current_driver(conn) do
    case get_current_user(conn) do
      %User{} = user ->
        user
        |> Ecto.assoc(:driver)
        |> Repo.one()
        |> Repo.preload([
          :user,
          :address,
          :schedules,
          :current_location,
          :devices,
          :vehicles
        ])

      _ ->
        nil
    end
  end

  def get_current_api_account(conn) do
    account = Guardian.Plug.current_resource(conn)

    Repo.preload(account, company: [locations: [:shippers]])
  end

  def set_user(conn, _params) do
    assign(conn, :current_user, get_current_user(conn))
  end

  def authorize_api_account(conn, _params) do
    case get_current_api_account(conn) do
      %ApiAccount{} = api_account -> assign(conn, :api_account, api_account)
      _ -> FallbackController.call(conn, {:error, :forbidden})
    end
  end

  def maybe_authorize_shipper(conn, _params \\ %{}) do
    shipper = get_current_shipper(conn)

    case get_current_user(conn) do
      user when (is_nil(user) and is_nil(shipper)) or not is_nil(shipper) ->
        conn
        |> assign(:current_shipper, shipper)
        |> assign(:current_shipper_id, Map.get(shipper || %{}, :id))

      _ ->
        FallbackController.call(conn, {:error, :forbidden})
    end
  end

  def authorize_shipper(conn, _params \\ %{}) do
    case get_current_shipper(conn) do
      %Shipper{} = shipper ->
        conn
        |> assign(:current_shipper, shipper)
        |> assign(:current_shipper_id, shipper.id)

      nil ->
        FallbackController.call(conn, {:error, :forbidden})
    end
  end

  def authorize_match(conn, _params \\ %{}) do
    match_id =
      Map.get(conn.params, "match_id") ||
        Map.get(conn.params, "id") || Map.get(conn.params, :id)

    shipper = Map.get(conn.assigns, :current_shipper) || Map.get(conn.assigns, :shipper)

    authorize_match_handler(conn, match_id, shipper)
  end

  def authorize_driver(conn, _params \\ %{}) do
    case get_current_driver(conn) do
      %Driver{} = driver -> assign(conn, :current_driver, driver)
      _ -> FallbackController.call(conn, {:error, :forbidden})
    end
  end

  def maybe_authorize_driver(conn, _params \\ %{}) do
    driver = get_current_driver(conn)

    case get_current_user(conn) do
      user when (is_nil(user) and is_nil(driver)) or not is_nil(driver) ->
        assign(conn, :current_driver, driver)

      _ ->
        FallbackController.call(conn, {:error, :forbidden})
    end
  end

  def authorize_driver_match(conn, _params \\ %{}),
    do:
      authorize_record(conn, :match, ["match_id", "id"],
        get_record: &Shipment.get_match/1,
        validator: &authorize_match_for_driver/3
      )

  def authorize_driver_match_stop(conn, _params \\ %{}),
    do:
      authorize_record(conn, :match_stop, ["stop_id", "id"],
        record_key: :match_stops,
        parent_keys: [:match],
        validator: fn _conn, stop, match -> {:ok, %{stop | match: match}} end
      )

  def authorize_driver_match_stop_item(conn, _params \\ %{}),
    do:
      authorize_record(conn, :match_stop_item, ["item_id", "id"],
        record_key: :items,
        parent_keys: [:match_stop]
      )

  def validate_driver_registration(conn, _params \\ %{}) do
    driver =
      conn
      |> get_current_driver()
      |> Repo.preload(
        images: DriverDocuments.latest_driver_documents_query(),
        vehicles: [images: DriverDocuments.latest_vehicle_documents_query()]
      )

    invalid_docs? =
      case DriverDocuments.validate_driver_documents(driver) do
        :ok ->
          false

        {:error, states} ->
          Keyword.get(states, :expired, 0) > 0 or Keyword.get(states, :rejected, 0) > 0
      end

    cond do
      invalid_docs? ->
        FallbackController.call(
          conn,
          {:error, :forbidden,
           "You have expired, rejected, or missing documents. Please contact support to continue."}
        )

      driver.state not in [:approved, :registered] ->
        FallbackController.call(
          conn,
          {:error, :forbidden, "You account is not active"}
        )

      true ->
        assign(conn, :current_driver, driver)
    end
  end

  def maybe_authorize_shipper_for_shipper(
        %{assigns: %{current_shipper: shipper}} = conn,
        _params \\ %{}
      ) do
    maybe_authorize_record(conn, :shipper, ["id"],
      get_record: fn id -> Accounts.get_account_shipper(shipper, id) end
    )
  end

  def authorize_shipper_for_api_account(
        %{
          assigns: %{api_account: %ApiAccount{company_id: company_id}},
          params: %{"shipper_email" => shipper_email}
        } = conn,
        _params
      ) do
    shipper = Accounts.get_shipper_by_email(shipper_email) |> Repo.preload(:location)

    case shipper do
      %Shipper{location: %Location{company_id: ^company_id}, state: :approved} ->
        conn |> assign_shipper(shipper)

      _ ->
        FallbackController.call(conn, {:error, :forbidden, "Invalid shipper"})
    end
  end

  def authorize_shipper_for_api_account(
        %{
          assigns: %{
            api_account: %ApiAccount{
              company: %Company{
                locations: [
                  %Location{shippers: [%Shipper{state: state} = shipper | _other_shippers]}
                  | _other_locations
                ]
              }
            }
          },
          params: _params
        } = conn,
        _empty_params
      )
      when state != :disabled,
      do: conn |> assign_shipper(shipper)

  def authorize_shipper_for_api_account(
        conn,
        _params
      ),
      do: conn |> FallbackController.call({:error, :forbidden, "Invalid shipper"})

  def build_live_session(conn, fields \\ []) do
    current_user = Auth.current_user(conn)
    current_user = put_in(current_user.admin.user, current_user)

    fields
    |> Enum.map(fn field ->
      value =
        case field do
          _ -> nil
        end

      {Atom.to_string(field), value}
    end)
    |> Enum.into(%{})
    |> Map.put("current_user", current_user)
  end

  def ensure_latest_version(%{assigns: %{version: version}} = conn, _params) do
    case version == Application.get_env(:frayt_elixir, :api_version) do
      true -> conn
      _ -> FallbackController.call(conn, {:error, :not_found})
    end
  end

  def ensure_latest_version(conn, _params),
    do: FallbackController.call(conn, {:error, :not_found})

  def update_driver_location(
        %{
          assigns: %{current_driver: driver},
          params: %{
            "location" => %{"latitude" => latitude, "longitude" => longitude}
          }
        } = conn,
        _
      ) do
    case Drivers.update_current_location(driver, %Geo.Point{coordinates: {longitude, latitude}}) do
      {:ok, driver} ->
        conn
        |> assign(:driver_location, driver.current_location)
        |> assign(:current_driver, driver)

      _ ->
        assign(conn, :driver_location, nil)
    end
  end

  def update_driver_location(conn, _),
    do: assign(conn, :driver_location, nil)

  defp assign_shipper(conn, %Shipper{user_id: user_id} = shipper) do
    ExAudit.track(user_id: user_id)

    assign(conn, :shipper, shipper)
  end

  defp authorize_match_handler(conn, match_id, _shipper) when is_nil(match_id),
    do: FallbackController.call(conn, {:error, :forbidden})

  defp authorize_match_handler(conn, match_id, shipper) do
    case Shipment.get_shipper_match(shipper, match_id) do
      %Match{} = match -> assign(conn, :match, match)
      nil -> FallbackController.call(conn, {:error, :forbidden})
    end
  end

  defp authorize_match_for_driver(conn, match, _) do
    %{current_driver: %Driver{id: driver_id} = driver} = conn.assigns

    case match do
      %Match{state: state} when state in [:canceled, :admin_canceled] ->
        {:error, :forbidden, "Sorry, the Shipper has canceled this Match"}

      %Match{state: :assigning_driver} = match ->
        case Drivers.validate_hidden_match(driver_id, match.id) do
          :ok -> {:ok, match}
          {:error, _} -> {:error, :forbidden}
        end

      %Match{driver_id: ^driver_id} = match ->
        {:ok, %{match | driver: driver}}

      %Match{driver_id: "" <> _} ->
        {:error, :forbidden, "Sorry, this Match has been accepted by another Driver"}

      _ ->
        {:error, :forbidden}
    end
  end

  @type validator :: (struct(), struct(), Plug.Conn.t() -> {:ok, struct()} | {:error, String.t()})
  @type authorize_record_opts ::
          {:record_key, atom()}
          | {:validator, validator()}
          | {:parent_keys, list(atom())}
          | {:get_record, (String.t() -> nil | struct())}

  @spec authorize_record(
          Plug.Conn.t(),
          atom(),
          list(String.t()),
          authorize_record_opts()
        ) :: Plug.Conn.t()
  defp authorize_record(conn, key, id_keys, opts),
    do: maybe_authorize_record(conn, key, id_keys, opts ++ [required: true])

  defp maybe_authorize_record(conn, key, id_keys, opts) do
    with id when not is_nil(id) <- find_by_keys(id_keys, conn.params),
         {parent, record} when not is_nil(record) <- get_record(conn, id, opts),
         {:ok, record} <- validate_record(conn, record, parent, opts) do
      assign(conn, key, record)
    else
      {:error, code, message} ->
        FallbackController.call(conn, {:error, code, message})

      {:error, code} ->
        FallbackController.call(conn, {:error, code})

      {_, nil} ->
        nil_or_forbidden(conn, key, opts[:required])

      nil ->
        nil_or_forbidden(conn, key, opts[:required])

      _ ->
        FallbackController.call(conn, {:error, :forbidden})
    end
  end

  defp nil_or_forbidden(conn, key, required) do
    if required,
      do: FallbackController.call(conn, {:error, :forbidden}),
      else: assign(conn, key, nil)
  end

  defp validate_record(conn, record, parent, opts) do
    if opts[:validator] do
      opts[:validator].(conn, record, parent)
    else
      {:ok, record}
    end
  end

  defp get_record(conn, id, opts) do
    cond do
      is_list(opts[:parent_keys]) ->
        with parent when not is_nil(parent) <- find_by_keys(opts[:parent_keys], conn.assigns) do
          parent = Repo.preload(parent, opts[:record_key])
          {parent, get_record_from_parent(parent, opts[:record_key], id)}
        end

      is_function(opts[:get_record]) ->
        {nil, opts[:get_record].(id)}
    end
  end

  defp find_by_keys(keys, map) do
    key = keys |> Enum.find(fn k -> k in Map.keys(map) end)

    key && Map.get(map, key)
  end

  defp get_record_from_parent(parent, key, id) do
    case Map.get(parent, key) do
      records when is_list(records) -> records |> Enum.find(&(&1.id == id))
      %_{id: ^id} = record -> record
      _ -> nil
    end
  end
end
