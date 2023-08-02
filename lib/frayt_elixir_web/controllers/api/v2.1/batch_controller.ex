defmodule FraytElixirWeb.API.V2x1.BatchController do
  use FraytElixirWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  alias FraytElixirWeb.API.V2x1.Schemas.{
    BatchRequest,
    BatchResponse,
    UnprocessibleEntity,
    InvalidParameters,
    Unauthorized,
    Forbidden,
    NotFound
  }

  alias FraytElixirWeb.API.V2x1.Callbacks

  alias FraytElixir.Shipment.{Address, DeliveryBatch, DeliveryBatches}
  alias FraytElixir.Accounts.{ApiAccount, Location, Shipper}
  alias FraytElixir.Repo
  alias FraytElixirWeb.FallbackController
  alias FraytElixirWeb.API.V2x1.BatchView

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_api_account: 2,
      authorize_shipper_for_api_account: 2
    ]

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  plug :authorize_api_account when action in [:create, :index, :delete, :show, :status]

  plug :authorize_shipper_for_api_account when action in [:create]

  action_fallback FraytElixirWeb.FallbackController

  tags ["batches"]

  security [%{"authorization" => []}]

  operation :create,
    summary: "Create a batch of routed matches",
    parameters: [],
    request_body: {"Batch params", "application/json", BatchRequest},
    callbacks: %{
      "batch_update" => %{
        "batch.shipper.location.company.webhook_url" => Callbacks.batch_webhook()
      },
      "match_update" => %{
        "batch.matches[].shipper.location.company.webhook_url" => Callbacks.match_webhook()
      }
    },
    responses: [
      ok: {"Batch response", "application/json", BatchResponse},
      unprocessable_entity:
        {"Invalid Batch parameters", "application/json",
         %Schema{type: :object, oneOf: [UnprocessibleEntity, InvalidParameters]}},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def create(
        %{
          body_params: %{origin_address: address} = batch_params,
          assigns: %{
            shipper: shipper
          }
        } = conn,
        _params
      ) do
    with geocoded_address <- Address.from_geocoding(address),
         batch_attrs <-
           batch_params
           |> OpenApiHelper.params_to_map()
           |> Map.put(:address, geocoded_address)
           |> Map.put(:service_level, 1),
         {:ok, %DeliveryBatch{} = batch} <-
           DeliveryBatches.create_delivery_batch(batch_attrs, shipper) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", RoutesApiV2_1.api_batch_path(conn, :show, batch))
      |> render("show.json", batch: batch)
    end
  end

  operation :show,
    summary: "Get a Batch",
    parameters: [
      id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        description: "Batch ID",
        example: "44e216c1-3ebc-4ce0-9a6b-1b94d9c2f25b",
        required: true
      ]
    ],
    responses: [
      ok: {"Batch response", "application/json", BatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def show(
        %{
          assigns: %{
            api_account: %ApiAccount{
              company_id: company_id
            }
          }
        } = conn,
        %{id: batch_id}
      ) do
    case DeliveryBatches.get_delivery_batch(batch_id) |> Repo.preload(shipper: [:location]) do
      %DeliveryBatch{shipper: %Shipper{location: %Location{company_id: ^company_id}}} = batch ->
        conn |> put_view(BatchView) |> render("show.json", batch: batch)

      %DeliveryBatch{} ->
        FallbackController.call(conn, {:error, :forbidden, "Invalid batch"})

      nil ->
        FallbackController.call(conn, {:error, :not_found})
    end
  end

  operation :delete,
    summary: "Cancels a Batch and any associated Matches",
    parameters: [
      id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        description: "Batch ID",
        example: "44e216c1-3ebc-4ce0-9a6b-1b94d9c2f25b",
        required: true
      ]
    ],
    responses: [
      ok: {"Batch response", "application/json", BatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def delete(
        %{
          assigns: %{
            api_account: %ApiAccount{
              company_id: company_id
            }
          }
        } = conn,
        %{id: batch_id}
      ) do
    batch =
      batch_id
      |> DeliveryBatches.get_delivery_batch()
      |> Repo.preload(matches: [:match_stops], shipper: [:location])

    with %DeliveryBatch{shipper: %Shipper{location: %Location{company_id: ^company_id}}} <- batch,
         {:ok, batch} <- DeliveryBatches.cancel_delivery_batch(batch) do
      conn |> put_view(BatchView) |> render("show.json", batch: batch)
    else
      %DeliveryBatch{} -> FallbackController.call(conn, {:error, :forbidden, "Invalid batch"})
      nil -> FallbackController.call(conn, {:error, :not_found})
    end
  end
end
