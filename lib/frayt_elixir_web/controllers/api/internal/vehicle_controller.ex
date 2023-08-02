defmodule FraytElixirWeb.API.Internal.VehicleController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.{Vehicle, Vehicles}
  alias FraytElixirWeb.SessionHelper
  alias FraytElixir.DriverDocuments
  alias FraytElixirWeb.UploadHelper
  alias Ecto.UUID

  import FraytElixir.AtomizeKeys

  action_fallback(FraytElixirWeb.FallbackController)
  plug :load_resource when action in [:show, :edit, :update, :dismiss_capacity]

  plug FraytElixirWeb.Authorize,
    policy: FraytElixir.Drivers.Vehicle.Policy,
    params: {__MODULE__, :extract_vehicle}

  defp load_resource(conn, _params) do
    vehicle_id = Map.get(conn.params, "vehicle_id") || Map.get(conn.params, "id")
    assign(conn, :vehicle, Vehicles.get_vehicle!(vehicle_id))
  end

  def extract_vehicle(conn), do: Map.get(conn.assigns, :vehicle, %{})

  defparams(
    create_vehicle_params(%{
      make!: :string,
      model!: :string,
      year!: :integer,
      vin!: :string,
      vehicle_class: :integer,
      license_plate: :string,
      insurance_photo!: :string,
      registration_photo!: :string,
      insurance_expiration_date!: :date,
      registration_expiration_date!: :date
    })
  )

  def create(conn, %{"vehicle" => vehicle_params}) do
    driver = SessionHelper.get_current_driver(conn)
    vehicle_params = atomize_keys(vehicle_params) |> Map.put(:driver_id, driver.id)

    %{
      insurance_photo: insurance_photo,
      registration_photo: registration_photo,
      insurance_expiration_date: insurance_expiration_date,
      registration_expiration_date: registration_expiration_date
    } = vehicle_params

    with %Ecto.Changeset{valid?: true} <- create_vehicle_params(vehicle_params) do
      with {:ok, vehicle} <- Vehicles.create_vehicle(vehicle_params),
           {:ok, _} <-
             create_vehicle_document(
               vehicle.id,
               "insurance",
               insurance_photo,
               insurance_expiration_date
             ),
           {:ok, _} <-
             create_vehicle_document(
               vehicle.id,
               "registration",
               registration_photo,
               registration_expiration_date
             ) do
        conn
        |> put_status(:created)
        |> render("show.json", vehicle: vehicle)
      end
    end
  end

  def update(conn, %{
        "id" => id,
        "capacity_between_wheel_wells" => wheel_well_width,
        "capacity_door_height" => door_height,
        "capacity_door_width" => door_width,
        "capacity_height" => cargo_area_height,
        "capacity_length" => cargo_area_length,
        "capacity_width" => cargo_area_width,
        "capacity_weight" => max_cargo_weight,
        "lift_gate" => lift_gate,
        "pallet_jack" => pallet_jack
      }) do
    driver = SessionHelper.get_current_driver(conn)

    with %Vehicle{} = vehicle <- Drivers.get_driver_vehicle(driver, id),
         {:ok, %Vehicle{} = vehicle} <-
           Drivers.update_vehicle_cargo_capacity(vehicle, %{
             wheel_well_width: wheel_well_width,
             door_height: door_height,
             door_width: door_width,
             cargo_area_height: cargo_area_height,
             cargo_area_length: cargo_area_length,
             cargo_area_width: cargo_area_width,
             max_cargo_weight: max_cargo_weight,
             pallet_jack: pallet_jack,
             lift_gate: lift_gate
           }) do
      render(conn, "show.json", vehicle: vehicle)
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  def update(conn, %{"id" => _, "vehicle" => vehicle_params}) do
    vehicle = conn.assigns.vehicle

    vehicle_params = atomize_keys(vehicle_params) |> Map.put(:driver_id, vehicle.driver_id)

    %{
      insurance_photo: insurance_photo,
      registration_photo: registration_photo,
      insurance_expiration_date: insurance_expiration_date,
      registration_expiration_date: registration_expiration_date
    } = vehicle_params

    with {:ok, vehicle} <- Vehicles.update_vehicle(vehicle, vehicle_params),
         {:ok, _} <-
           create_vehicle_document(
             vehicle.id,
             "insurance",
             insurance_photo,
             insurance_expiration_date
           ),
         {:ok, _} <-
           create_vehicle_document(
             vehicle.id,
             "registration",
             registration_photo,
             registration_expiration_date
           ) do
      conn
      |> put_status(:ok)
      |> render("show.json", vehicle: vehicle)
    end
  end

  def dismiss_capacity(conn, _params) do
    vehicle = conn.assigns.vehicle

    case Drivers.touch_vehicle(vehicle) do
      {:ok, %Vehicle{} = vehicle} -> render(conn, "show.json", vehicle: vehicle)
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  defp create_vehicle_document(vehicle_id, type, document, expires_at) do
    with {:ok, photo} <-
           UploadHelper.file_from_base64(document, "#{type}.jpg", "#{UUID.generate()}-#{type}") do
      DriverDocuments.create_vehicle_document(%{
        type: type,
        expires_at: expires_at,
        document: photo,
        state: :pending_approval,
        vehicle_id: vehicle_id
      })
    end
  end
end
