defmodule FraytElixirWeb.API.Internal.DriverController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixir.Payments
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver
  alias FraytElixirWeb.UploadHelper
  alias FraytElixir.DriverDocuments
  alias Ecto.UUID
  import FraytElixir.AtomizeKeys

  require Logger

  import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]

  plug(:authorize_driver when action in [:update, :show])

  action_fallback(FraytElixirWeb.FallbackController)

  defparams(
    create_driver_params(%{
      user: %{
        email!: :string,
        password!: :string
      },
      phone_number!: :string,
      market_id!: :string,
      signature!: :string,
      english_proficiency!: :string,
      vehicle_class!: :string,
      agreements!: [
        %{
          document_id!: :string,
          agreed!: :boolean
        }
      ]
    })
  )

  defparams(
    update_driver_identity_params(%{
      license_photo!: :string,
      license_expiration_date!: :date,
      profile_photo!: :string,
      license_number!: :string,
      ssn!: :string
    })
  )

  def create(conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- create_driver_params(params) do
      attrs = Params.to_map(changeset)
      agreements = Enum.map(attrs.agreements, &Map.put(&1, :signature, attrs.signature))

      with {:ok, driver} <- Drivers.create_driver(%{attrs | agreements: agreements}),
           {:ok, token, _claims} <- FraytElixir.Guardian.encode_and_sign(%{id: driver.user_id}) do
        conn
        |> put_status(:created)
        |> put_view(FraytElixirWeb.SessionView)
        |> render("authenticate_driver.json", driver: driver, token: token)
      end
    end
  end

  def show(%{assigns: %{current_driver: driver}} = conn, _params) do
    render(conn, "show.json", driver: driver)
  end

  def update(%{assigns: %{current_driver: driver}} = conn, %{"driver" => driver_params}) do
    with {:ok, %Driver{} = driver} <- Drivers.update_driver(driver, driver_params) do
      render(conn, "show.json", driver: driver)
    end
  end

  def update(
        %{assigns: %{current_driver: driver}} = conn,
        %{
          "current_password" => current,
          "password" => new,
          "password_confirmation" => confirmation
        }
      ) do
    with {:ok, _user} <-
           Drivers.change_password(driver.user, %{
             current: current,
             new: new,
             confirmation: confirmation
           }) do
      send_resp(conn, :no_content, "")
    end
  end

  def update(
        %{assigns: %{current_driver: driver}} = conn,
        %{"password" => password, "password_confirmation" => password_confirmation}
      ) do
    with {:ok, _user} <-
           Drivers.set_initial_password(driver.user, password, password_confirmation) do
      send_resp(conn, :no_content, "")
    end
  end

  def update(
        %{assigns: %{current_driver: driver}} = conn,
        %{
          "license_photo" => license_photo,
          "license_expiration_date" => license_expiration_date,
          "profile_photo" => profile_photo,
          "license_number" => license_number,
          "ssn" => ssn
        } = params
      ) do
    with %Ecto.Changeset{valid?: true} <- update_driver_identity_params(params) do
      with {:ok, %Driver{id: driver_id}} <-
             Drivers.update_driver(driver, %{
               license_number: license_number,
               ssn: ssn
             }),
           {:ok, _} <-
             create_driver_document(driver_id, "license", license_photo, license_expiration_date),
           {:ok, _} <-
             create_driver_document(driver_id, "profile", profile_photo, nil),
           driver <-
             Drivers.get_driver!(driver_id)
             |> FraytElixir.Repo.preload(
               [images: DriverDocuments.latest_driver_documents_query()],
               force: true
             ) do
        render(conn, "show.json", driver: driver)
      end
    end
  end

  def update(%{assigns: %{current_driver: driver}} = conn, %{"profile_photo" => profile_photo}) do
    with {:ok, file} <-
           UploadHelper.file_from_base64(profile_photo, "profile_photo.jpg", :profile_photo),
         {:ok, %Driver{} = driver} <- Drivers.update_driver(driver, %{profile_photo: file}) do
      render(conn, "show.json", driver: driver)
    end
  end

  # TODO: We need to refactor this mess...
  def update(%{assigns: %{current_driver: driver}} = conn, %{"vehicle_photos" => photos}) do
    if Enum.any?(photos, &is_nil(elem(&1, 1))) do
      {:error, "All the vehicle photos are required to be uploaded"}
    else
      %{vehicles: [vehicle | _]} = driver = Drivers.get_driver!(driver.id)

      # TODO: Validate unloaded photos
      Enum.each(photos, fn {type, document} ->
        document = atomize_keys(document)

        DriverDocuments.create_vehicle_document(%{
          type: type,
          state: :pending_approval,
          expires_at: nil,
          document: document,
          vehicle_id: vehicle.id
        })
      end)

      render(conn, "show.json", driver: driver)
    end
  end

  def update(
        %{assigns: %{current_driver: driver = %Driver{vehicles: [%{vehicle_class: 4} | _]}}} =
          conn,
        %{"state" => "pending_approval"}
      ) do
    with {:ok, %Driver{} = driver} <- Drivers.complete_driver_application(driver),
         {:ok, %Driver{} = driver} <- Drivers.update_driver_state(driver, :pending_approval) do
      render(conn, "show.json", driver: driver)
    end
  end

  def update(%{assigns: %{current_driver: driver}} = conn, %{"can_load" => can_load}) do
    with {:ok, %Driver{} = driver} <-
           Drivers.update_driver(driver, %{can_load: can_load}) do
      render(conn, "show.json", driver: driver)
    end
  end

  def update(
        %{assigns: %{current_driver: driver}} = conn,
        %{"ssn" => ssn, "agree_to_tos" => agree_to_tos}
      ) do
    if agree_to_tos do
      with {:ok, %Driver{} = driver} <- Drivers.update_driver(driver, %{ssn: ssn}),
           {:ok, driver} <- Payments.create_wallet(driver) do
        render(conn, "show.json", driver: driver)
      end
    else
      {:error, "Must agree to Branch Terms of Service to create your wallet"}
    end
  end

  def update(%{assigns: %{current_driver: driver}} = conn, %{"state" => "registered"}) do
    with {:ok, %Driver{} = driver} <-
           Drivers.update_driver_state(driver, :registered) do
      render(conn, "show.json", driver: driver)
    end
  end

  def update(
        %{assigns: %{current_driver: driver}} = conn,
        %{
          "schedule_notifications_opt_in" => opted_in
        }
      ) do
    fleet_opt_state =
      case opted_in do
        "true" -> :opted_in
        "false" -> :opted_out
      end

    with {:ok, %Driver{} = driver} <-
           Drivers.update_driver(driver, %{fleet_opt_state: fleet_opt_state}) do
      render(conn, "show.json", driver: driver)
    end
  end

  def update(%{assigns: %{current_driver: driver}} = conn, params) do
    account_params =
      params
      |> case do
        %{"address" => address, "city" => city, "state" => state, "zip" => zip} = address_map ->
          %{
            address: %{
              address: address,
              address2: Map.get(address_map, "address2"),
              city: city,
              state: state,
              zip: zip,
              id: driver.address_id
            }
          }

        _ ->
          %{}
      end
      |> Map.merge(
        params
        |> Map.take(["first_name", "last_name", "phone_number", "birthdate"])
        |> atomize_keys()
      )

    with {:ok, %Driver{} = driver} <- Drivers.update_driver(driver, account_params) do
      render(conn, "show.json", driver: driver)
    end
  end

  defp create_driver_document(driver_id, type, document, expires_at) do
    with {:ok, photo} <-
           UploadHelper.file_from_base64(document, "#{type}.jpg", "#{UUID.generate()}-#{type}") do
      DriverDocuments.create_driver_document(%{
        type: type,
        state: :pending_approval,
        document: photo,
        expires_at: expires_at,
        driver_id: driver_id
      })
    end
  end
end
