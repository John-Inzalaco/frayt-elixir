defmodule FraytElixirWeb.API.V2x1.MatchView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.V2x1.MatchView

  alias FraytElixirWeb.{
    MatchStopItemView,
    MatchFeeView,
    ContactView,
    AddressView,
    DriverView,
    ETAView
  }

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{MatchStop, Match}

  def render("index.json", %{matches: matches}) do
    %{response: render_many(matches, MatchView, "match.json")}
  end

  def render("show.json", %{match: match}) do
    %{response: render_one(match, MatchView, "match.json")}
  end

  def render("match.json", %{
        match:
          %Match{
            match_stops: [
              %MatchStop{
                has_load_fee: has_load_fee,
                needs_pallet_jack: needs_pallet_jack,
                self_recipient: self_recipient,
                recipient: recipient,
                destination_address: destination_address,
                items: items,
                delivery_notes: delivery_notes
              }
            ],
            total_weight: total_weight,
            total_volume: total_volume,
            amount_charged: amount_charged,
            contract: contract,
            unload_method: unload_method,
            self_sender: self_sender,
            fees: fees,
            eta: eta
          } = match
      }) do
    %{
      id: match.id,
      distance: match.total_distance,
      tip_price: Shipment.get_match_fee_price(match, :driver_tip, :shipper),
      total_price: amount_charged,
      service_level: match.service_level,
      vehicle_class: match.vehicle_class,
      has_load_fee: has_load_fee,
      needs_pallet_jack: needs_pallet_jack,
      load_fee_price: Shipment.get_match_fee_price(match, :load_fee, :shipper),
      price: Shipment.get_match_fee_price(match, :base_fee, :shipper),
      dropoff_at: match.dropoff_at,
      pickup_at: match.pickup_at,
      scheduled: match.scheduled,
      pickup_notes: match.pickup_notes,
      delivery_notes: delivery_notes,
      po: match.po,
      shortcode: match.shortcode,
      identifier: match.identifier,
      sender: render_one(match.sender, ContactView, "contact.json"),
      self_sender: self_sender,
      self_recipient: self_recipient,
      recipient: render_one(recipient, ContactView, "contact.json"),
      total_weight: total_weight,
      total_volume: total_volume,
      state: Shipment.get_deprecated_match_state(match),
      origin_address: render_one(match.origin_address, AddressView, "address.json"),
      destination_address: render_one(destination_address, AddressView, "address.json"),
      inserted_at: match.inserted_at,
      driver: DriverView.render("driver.json", match),
      items: render_many(items, MatchStopItemView, "match_stop_item.json"),
      fees: render_many(fees, MatchFeeView, "shipper_match_fee.json"),
      contract: contract && contract.contract_key,
      unload_method: unload_method,
      eta: render_one(eta, ETAView, "eta.json")
    }
  end
end
