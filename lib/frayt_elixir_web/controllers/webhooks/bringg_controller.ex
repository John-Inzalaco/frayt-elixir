defmodule FraytElixirWeb.Webhook.BringgController do
  use FraytElixirWeb, :controller
  use Params

  alias Ecto.Changeset
  alias FraytElixirWeb.FallbackController
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.Company
  alias FraytElixir.Shipment
  alias FraytElixir.Integrations.Bringg
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Accounts.Location
  alias FraytElixir.Accounts.Shipper
  alias FraytElixir.Matches

  @bringg_client Application.compile_env(:frayt_elixir, :bringg_client)

  plug(:authorize_bringg)
  plug(:validate_bringg_match when action in [:update, :cancel])

  action_fallback(FallbackController)

  defparams(
    create_match_params(%{
      id!: :integer,
      external_id: :string,
      tip: :integer,
      customer: %{
        email: :string,
        name: :string,
        phone: :string
      },
      notes: [
        %{
          note: :string
        }
      ],
      way_points!: [
        %{
          id!: :integer,
          address!: :string,
          address_second_line: [field: :string, default: ""],
          city!: :string,
          zipcode!: :string,
          state: [field: :string, default: ""],
          lat: :float,
          lng: :float,
          scheduled_at: :utc_datetime,
          inventory!: [
            %{
              id!: :integer,
              height!: :integer,
              length!: :integer,
              weight!: :integer,
              width!: :integer,
              original_quantity!: :integer,
              name!: :string,
              price!: :integer
            }
          ],
          pickup_dropoff_option!: :string,
          notes: [
            %{
              note: :string
            }
          ]
        }
      ]
    })
  )

  defparams(
    update_match_params(%{
      delivery_id!: :string,
      task_id!: :integer,
      task_note: %{note: :string, way_point_id: :integer},
      task_inventory: %{original_quantity: :integer, id!: :integer},
      way_point: %{
        position: :integer,
        name: :string,
        email: :string,
        phone: :string,
        address: :string,
        address_line_2: :string,
        lat: :float,
        lng: :float,
        city: :string,
        zipcode: :string,
        state: :string,
        scheduled_at: :utc_datetime
      }
    })
  )

  defparams(
    cancel_match_params(%{
      delivery_id!: :string,
      reason_id: :integer,
      reason: :string
    })
  )

  defparams(
    company_registered_params(%{
      merchant_uuid!: :string
    })
  )

  def create(
        %{
          assigns: %{
            company: company
          }
        } = conn,
        params
      ) do
    with %Changeset{valid?: true} = changeset <-
           Bringg.sanitize_match_params(params) |> create_match_params(),
         match_attrs <-
           Params.to_map(changeset),
         shipper <- Shipment.get_company_shipper(company),
         {:ok, match} <-
           match_attrs
           |> Bringg.convert_params()
           |> Matches.convert_attrs_to_multi_stop()
           |> Matches.create_match(shipper) do
      render(conn, "success.json", %{match_id: match.id})
    else
      {:error, _, changeset, data} ->
        {:error, :bringg_error, changeset, data}
    end
  end

  def update(
        %{
          assigns: %{
            match: match
          }
        } = conn,
        params
      ) do
    with %Ecto.Changeset{valid?: true} = changeset <- update_match_params(params),
         match_attrs <- Params.to_map(changeset),
         {:ok, %{validate_match: _updated_match}} <-
           Bringg.update_match(match, match_attrs) do
      render(conn, "success.json", %{match_id: match.id})
    else
      {:error, _, changeset, data} ->
        {:error, :bringg_error, changeset, data}
    end
  end

  def cancel(%{assigns: %{match: match}} = conn, match_params) do
    with %Ecto.Changeset{valid?: true} = changeset <- cancel_match_params(match_params),
         match_attrs <- Params.to_map(changeset),
         {:ok, %Match{} = match} <- Bringg.cancel_match(match, match_attrs) do
      render(conn, "success.json", %{match_id: match.id})
    end
  end

  def merchant_registered(conn, params) do
    with %Changeset{valid?: true} = _changeset <-
           company_registered_params(params),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           @bringg_client.get_merchant_creds(params["merchant_uuid"]),
         {:ok, body} <- Jason.decode(body),
         {:ok, %Company{}} <-
           Accounts.create_company(%{
             name: body["merchant_name"],
             integration_id: body["merchant_uuid"],
             integration: :bringg,
             api_key: body["credentials"]["api_key"],
             webhook_config: %{
               client_id: body["credentials"]["client_id"],
               secret: body["credentials"]["client_secret"]
             }
           }) do
      render(conn, "success.json", %{merchant_uuid: body["merchant_uuid"]})
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, :bad_request, reason}

      error ->
        error
    end
  end

  def authorize_bringg(conn, _params) do
    with ["Bearer " <> api_key] <- get_req_header(conn, "authorization"),
         %Company{} = company <-
           Accounts.get_company_by_api_key(api_key) do
      assign(conn, :company, company)
    else
      _ -> FallbackController.call(conn, {:error, :forbidden})
    end
  end

  def validate_bringg_match(
        %{
          assigns: %{company: %Company{id: company_id}},
          params: %{"delivery_id" => match_id}
        } = conn,
        _
      ) do
    case Shipment.get_match(match_id) do
      %Match{shipper: %Shipper{location: %Location{company_id: ^company_id}}} = match ->
        assign(conn, :match, match)

      _ ->
        FallbackController.call(conn, {:error, :forbidden})
    end
  end
end
