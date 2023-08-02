defmodule FraytElixirWeb.Admin.DeliveryBatchController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Shipment.DeliveryBatches
  alias FraytElixirWeb.FallbackController
  alias FraytElixirWeb.DisplayFunctions

  action_fallback FallbackController

  def create(
        conn,
        %{
          "deliveries" =>
            %{
              "csv" => csv
            } = delivery_params
        }
      ) do
    case DeliveryBatches.create_delivery_batch_from_csv(delivery_params, csv) do
      {:ok, batch} ->
        redirect(conn, to: Routes.batches_path(conn, :index, state: nil, query: batch.id))

      {:error, %Ecto.Changeset{} = changeset} ->
        send_flash(conn, :error, DisplayFunctions.humanize_errors(changeset))

      {:error, error} ->
        send_flash(conn, :error, "Error: #{inspect(error)}")
    end
  end

  defp send_flash(conn, type, message),
    do:
      conn
      |> put_flash(type, message)
      |> redirect(to: Routes.create_multistop_path(conn, :create))
end
