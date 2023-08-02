defmodule FraytElixirWeb.API.Internal.BackgroundCheckController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixir.Screenings

  import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]

  plug :authorize_driver

  defparams(create_background_check_params(%{method_id!: :string, intent_id: :string}))

  action_fallback FraytElixirWeb.FallbackController

  def create(%{assigns: %{current_driver: driver}} = conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- create_background_check_params(params),
         :ok <- validate_driver_is_not_box_truck(driver) do
      attrs = Params.to_map(changeset)

      case Screenings.authorize_background_check(driver, attrs) do
        {:ok, {driver, payment_res}} ->
          conn
          |> put_status(201)
          |> render("payment_result.json", driver: driver, result: payment_res)

        {:error, error} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render("payment_result.json", error: error)
      end
    end
  end

  @box_truck 4
  defp validate_driver_is_not_box_truck(%{vehicles: vehicles} = _driver) do
    case Enum.any?(vehicles, &(&1.vehicle_class == @box_truck)) do
      true -> {:error, "Background check payments are not needed for box truck drivers"}
      false -> :ok
    end
  end
end
