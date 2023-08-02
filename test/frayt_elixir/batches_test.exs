defmodule FraytElixir.BatchesTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.Batch

  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor

  setup :start_match_supervisor

  describe "batches" do
    test "create/2 with valid data creates numerous matches" do
      csv = %Plug.Upload{
        path: "test/fixtures/batch_match.csv",
        filename: "batch_match.csv"
      }

      shipper = insert(:shipper_with_location)

      %{id: contract_id} =
        insert(:contract,
          contract_key: "atd",
          pricing_contract: :atd,
          company: shipper.location.company
        )

      assert {:ok,
              %{
                "validate_match_0" => %{
                  state: :inactive,
                  contract_id: ^contract_id,
                  service_level: 1,
                  total_distance: 5.0,
                  po: nil,
                  vehicle_class: 1,
                  identifier: nil,
                  driver_fees: driver_fees,
                  driver_total_pay: driver_total_pay,
                  scheduled: true,
                  fees: [
                    %FraytElixir.Shipment.MatchFee{
                      amount: base_fee,
                      type: :base_fee
                    },
                    %FraytElixir.Shipment.MatchFee{
                      amount: 625,
                      driver_amount: 625,
                      type: :driver_tip
                    }
                  ],
                  match_stops: [
                    %{
                      destination_address: %{
                        address: "708 Walnut Street",
                        address2: "500",
                        city: "Cincinnati",
                        country: "United States",
                        country_code: "US",
                        county: "Hamilton County",
                        formatted_address: "1311 Vine Street, Cincinnati OH 45202",
                        state: "Ohio",
                        zip: "45202"
                      },
                      items: [
                        %{
                          description: "TWO DOZEN ASSORTED ROSES",
                          height: 10.0,
                          width: 10.0,
                          length: 10.0,
                          weight: 25.0,
                          pieces: 1
                        }
                      ],
                      destination_photo_required: false,
                      recipient: %{
                        email: "recipient@email.com",
                        name: "jessie graham",
                        phone_number: %ExPhoneNumber.Model.PhoneNumber{
                          country_code: 1,
                          national_number: 513_402_0000
                        }
                      }
                    }
                  ]
                }
              }} = Batch.create(csv, shipper)

      assert base_fee > 0
      assert driver_fees >= 0
      assert driver_total_pay > 0
    end

    test "create/2 with invalid data returns errors" do
      csv = %Plug.Upload{
        path: "test/fixtures/bad_batch_match.csv",
        filename: "bad_batch_match.csv"
      }

      shipper = insert(:shipper_with_location)

      assert {:error, "update_match_0",
              %{
                valid?: false
              }, %{}} = Batch.create(csv, shipper)
    end
  end
end
