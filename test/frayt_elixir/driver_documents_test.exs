defmodule FraytElixir.DriverDocumentsTest do
  use FraytElixir.DataCase
  import FraytElixir.Factory

  alias Ecto.UUID
  alias FraytElixir.Repo
  alias FraytElixir.DriverDocuments
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.{VehicleDocument, DriverDocument}

  describe "test vehicle document functions" do
    test "get_latest_vehicle_document/2" do
      %{id: vehicle_id} = vehicle = insert(:vehicle, images: [])

      %{id: correct_id} =
        insert(:vehicle_document,
          type: "insurance",
          inserted_at: ~N[2020-03-21 12:23:21],
          expires_at: ~N[2030-03-21 12:23:21],
          vehicle: vehicle
        )

      latest_insurance = DriverDocuments.get_latest_vehicle_document(vehicle_id, "insurance")
      assert latest_insurance.id == correct_id
    end

    test "create_vehicle_document/1" do
      %{id: vehicle_id} = insert(:vehicle, images: [])

      assert Repo.all(VehicleDocument) == []

      DriverDocuments.create_vehicle_document(%{
        type: "registration",
        expires_at: ~N[2030-03-21 12:23:21],
        state: "approved",
        document: %{binary: "content"},
        vehicle_id: vehicle_id
      })

      [vehicle_document] = Repo.all(VehicleDocument)
      assert vehicle_document.document.file_name =~ "registration"
      assert vehicle_document.type == :registration
      assert vehicle_document.vehicle_id == vehicle_id
    end
  end

  describe "test driver document functions" do
    test "create_driver_document/1" do
      driver = insert(:driver, images: [])

      assert Repo.all(DriverDocument) == []

      DriverDocuments.create_driver_document(%{
        driver_id: driver.id,
        type: "license",
        expires_at: ~N[2030-03-21 12:23:21],
        document: %{filename: "license_photo-#{UUID.generate()}.jpeg", binary: "content"}
      })

      [driver_document | _] = Repo.all(DriverDocument)
      assert driver_document.document.file_name =~ "license"
      assert driver_document.type == :license
      assert driver_document.driver_id == driver.id
    end

    test "get_latest_driver_document/1" do
      driver = insert(:driver, images: [])

      insert(:driver_document,
        type: "license",
        driver_id: driver.id,
        state: "approved",
        document: %{file_name: "test/drivers-license.jpeg", updated_at: DateTime.utc_now()},
        expires_at: "2020-01-01T23:59:59Z",
        inserted_at: ~N[2010-01-01 00:00:00]
      )

      %{id: correct_id} =
        insert(:driver_document,
          type: "license",
          driver_id: driver.id,
          state: "approved",
          document: %{file_name: "test/drivers-license.jpeg", updated_at: DateTime.utc_now()},
          inserted_at: ~N[2021-01-01 00:00:00],
          expires_at: "2030-01-01T23:59:59Z"
        )

      assert DriverDocuments.get_latest_driver_document(driver.id, "license").id == correct_id
    end
  end

  describe "test create_vehicle_document/1 function" do
    test "fails when document input(s) are invalid" do
      vehicle_id = UUID.generate()

      assert {:error, %{errors: errors}} =
               DriverDocuments.create_vehicle_document(%{
                 type: :invalid_doc_type,
                 expires_at: "invlida_date",
                 document: nil,
                 state: :invalidad_state,
                 vehicle_id: vehicle_id
               })

      expected_errors = [
        document: {"can't be blank", [validation: :required]},
        type:
          {"is invalid", [type: FraytElixir.Drivers.VehicleDocumentType.Type, validation: :cast]},
        expires_at: {"is invalid", [type: :date, validation: :cast]},
        state: {"is invalid", [type: FraytElixir.Document.State.Type, validation: :cast]}
      ]

      assert expected_errors == errors
    end

    test "fails when vehicle doesn't exists" do
      vehicle_id = UUID.generate()

      assert_raise Ecto.ConstraintError, fn ->
        DriverDocuments.create_vehicle_document(%{
          type: :insurance,
          expires_at: "2030-01-01T00:00:00Z",
          document: %{filename: "license_photo-#{vehicle_id}.jpeg", binary: "content"},
          state: :pending_approval,
          vehicle_id: vehicle_id
        })
      end
    end

    test "success when document_type is valid" do
      vehicle = insert(:vehicle)

      assert {:ok, _} =
               DriverDocuments.create_vehicle_document(%{
                 type: :insurance,
                 expires_at: "2030-01-01T00:00:00Z",
                 document: %{filename: "license_photo-#{vehicle.id}.jpeg", binary: "content"},
                 state: :pending_approval,
                 vehicle_id: vehicle.id
               })
    end
  end

  describe "driver assets" do
    test "get_s3_asset/2 :profile_photo returns a presigned url" do
      driver = insert(:profiled_driver)
      assert {:ok, _presigned_url} = DriverDocuments.get_s3_asset(:profile_photo, driver)
    end

    test "get_s3_asset/2 :profile_photo and unprofiled driver returns an error" do
      driver = insert(:driver)
      assert {:error, _message} = DriverDocuments.get_s3_asset(:profile_photo, driver)
    end

    test "get_s3_asset/2 invalid atom and profiled driver returns an error" do
      driver = insert(:profiled_driver)
      assert {:error, _message} = DriverDocuments.get_s3_asset(:invalid_atom, driver)
    end
  end

  describe "review_driver_documents/2" do
    test "succeed for a new driver" do
      %{
        id: driver_id,
        images: [%{id: image_1}, %{id: image_2}],
        vehicles: [%{id: vehicle_id, images: [%{id: vehicle_image_1}, %{id: vehicle_image_2}]}]
      } =
        driver =
        insert(:driver,
          state: :pending_approval,
          images: [
            build(:driver_document,
              type: :profile,
              state: :pending_approval,
              expires_at: "2030-01-01"
            ),
            build(:driver_document,
              type: :license,
              state: :pending_approval,
              expires_at: "2030-01-01",
              inserted_at: DateTime.utc_now()
            )
          ],
          vehicles: [
            build(:vehicle,
              images: [
                build(:vehicle_document,
                  type: :registration,
                  state: :pending_approval,
                  expires_at: "2030-01-01"
                ),
                build(:vehicle_document,
                  type: :insurance,
                  state: :pending_approval,
                  expires_at: "2030-01-01"
                )
              ]
            )
          ]
        )

      attrs = %{
        "images" => %{
          "0" => %{"id" => image_1, "state" => :approved},
          "1" => %{"id" => image_2, "state" => :approved}
        },
        "vehicles" => %{
          "0" => %{
            "id" => vehicle_id,
            "images" => %{
              "0" => %{"id" => vehicle_image_1, "state" => :approved},
              "1" => %{"id" => vehicle_image_2, "state" => :approved}
            }
          }
        }
      }

      assert {:ok,
              %FraytElixir.Drivers.Driver{
                id: ^driver_id,
                images: [%{state: :approved}, %{state: :approved}],
                vehicles: [%{id: ^vehicle_id, images: [%{state: :approved}, %{state: :approved}]}]
              }} = DriverDocuments.review_driver_documents(driver, attrs)
    end

    test "succeed for a existing driver" do
      %{
        id: driver_id,
        images: [%{id: _image_1}, %{id: image_2}],
        vehicles: [%{id: vehicle_id, images: [%{id: vehicle_image_1}, %{id: vehicle_image_2}]}]
      } =
        insert(:driver,
          state: :approved,
          images: [
            build(:driver_document,
              type: :license,
              state: :approved,
              expires_at: "2020-01-01",
              inserted_at: DateTime.utc_now() |> DateTime.add(-60, :second)
            ),
            build(:driver_document,
              type: :profile,
              state: :approved,
              expires_at: "2030-01-01"
            )
          ],
          vehicles: [
            build(:vehicle,
              images: [
                build(:vehicle_document,
                  type: :registration,
                  state: :approved,
                  expires_at: "2030-01-01"
                ),
                build(:vehicle_document,
                  type: :insurance,
                  state: :approved,
                  expires_at: "2030-01-01"
                )
              ]
            )
          ]
        )

      {:ok, %{id: new_license_id}} =
        DriverDocuments.create_driver_document(%{
          driver_id: driver_id,
          type: :license,
          state: :pending_approval,
          expires_at: "2030-01-01",
          document: %{
            file_name: "test/license.jpeg",
            inserted_at: DateTime.utc_now() |> DateTime.add(30, :second),
            binary: "content"
          }
        })

      attrs = %{
        "images" => %{
          "0" => %{"id" => new_license_id, "expires_at" => "2030-01-01", "state" => :approved},
          "1" => %{"id" => image_2, "state" => :approved}
        },
        "vehicles" => %{
          "0" => %{
            "id" => vehicle_id,
            "images" => %{
              "0" => %{"id" => vehicle_image_1, "state" => :approved},
              "1" => %{"id" => vehicle_image_2, "state" => :approved}
            }
          }
        }
      }

      driver =
        Drivers.get_driver(driver_id)
        |> Repo.preload(
          images: DriverDocuments.latest_driver_documents_query(),
          vehicles: [images: DriverDocuments.latest_vehicle_documents_query()]
        )

      assert {:ok,
              %FraytElixir.Drivers.Driver{
                id: ^driver_id,
                images: [%{id: ^new_license_id, state: :approved}, %{state: :approved}],
                vehicles: [%{id: ^vehicle_id, images: [%{state: :approved}, %{state: :approved}]}]
              }} = DriverDocuments.review_driver_documents(driver, attrs)
    end
  end
end
