defmodule FraytElixirWeb.API.Internal.ShipperDriverController do
  use FraytElixirWeb, :controller
  use FraytElixir.Schema
  use Params.Schema, %{email: :string}

  import FraytElixirWeb.SessionHelper, only: [authorize_shipper: 2]

  alias FraytElixir.Drivers

  plug(:authorize_shipper when action in [:index])

  action_fallback(FraytElixirWeb.FallbackController)

  def index(%{assigns: %{current_shipper: shipper}} = conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- from(params, with: &params_validator/2) do
      filter = Params.to_map(changeset)
      drivers = Drivers.list_drivers_for_shipper(shipper, filter)

      render(conn, "index.json", drivers: drivers)
    end
  end

  def params_validator(data, params) do
    cast(data, params, [:email])
    |> validate_email_format(:email)
  end
end
