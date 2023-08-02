defmodule FraytElixirWeb.MatchStopViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.MatchStopView
  alias FraytElixir.Shipment.{MatchStop}

  import FraytElixir.Factory

  test "rendered match returns correct values" do
    destination_address = insert(:address, geo_location: findlay_market_point())

    %MatchStop{
      id: id,
      has_load_fee: has_load_fee,
      needs_pallet_jack: needs_pallet_jack,
      recipient: %{
        id: recipient_id
      },
      items: [
        %{
          description: description,
          width: width,
          height: height,
          weight: weight,
          length: length,
          pieces: pieces
        }
      ]
    } =
      match_stop =
      insert(:match_stop,
        destination_address: destination_address,
        signature_photo: %{file_name: "signature_photo.png", updated_at: DateTime.utc_now()},
        destination_photo: %{
          file_name: "destination_photo.png",
          updated_at: DateTime.utc_now()
        }
      )

    insert(:match_stop_state_transition, to: :pending, match_stop: match_stop)

    assert %{
             delivery_notes: nil,
             destination_photo: "some_url",
             has_load_fee: ^has_load_fee,
             needs_pallet_jack: ^needs_pallet_jack,
             id: ^id,
             items: [
               %{
                 "description" => ^description,
                 "width" => ^width,
                 "height" => ^height,
                 "weight" => ^weight,
                 "length" => ^length,
                 "pieces" => ^pieces
               }
             ],
             signature_photo: "some_url",
             recipient: %{
               id: ^recipient_id
             },
             self_recipient: false,
             state: :pending,
             state_transition: %{
               to: :pending
             }
           } = MatchStopView.render("match_stop.json", %{match_stop: match_stop})
  end
end
