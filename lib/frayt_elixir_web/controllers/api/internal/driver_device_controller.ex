defmodule FraytElixirWeb.API.Internal.DriverDeviceController do
  use FraytElixirWeb, :controller
  use Params
  alias FraytElixir.Devices
  alias FraytElixir.Notifications.DriverNotification
  alias FraytElixirWeb.ChangesetParams

  require Logger

  import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]

  plug(:authorize_driver when action in [:create, :send_test_notification])

  action_fallback(FraytElixirWeb.FallbackController)

  defparams(
    device_params(%{
      device: %{
        device_uuid!: :string,
        player_id!: :string,
        device_model: :string,
        os: :string,
        os_version: :string,
        app_version: :string,
        app_revision: :string,
        app_build_number: :integer,
        is_tablet: :boolean,
        is_location_enabled: :boolean
      }
    })
  )

  def create(%{assigns: %{current_driver: driver}} = conn, params) do
    params = device_params(params)

    with {:ok, %{device: attrs}} <- ChangesetParams.get_data(params),
         {:ok, driver} <- Devices.upsert_driver_device(driver, attrs) do
      render(conn, "show.json", device: driver.default_device)
    end
  end

  def send_test_notification(%{assigns: %{current_driver: driver}} = conn, _params) do
    with {:ok, _} <- DriverNotification.send_test_notification(driver) do
      render(conn, "success.json", %{})
    end
  end
end
