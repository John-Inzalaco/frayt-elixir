defmodule FraytElixirWeb.API.V2x1.BatchView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.V2x1.BatchView
  alias FraytElixirWeb.API.Internal.{ShipperView, MatchView}

  alias FraytElixirWeb.{
    StateTransitionView,
    AddressView,
    LocationView,
    MatchStopView
  }

  alias FraytElixir.Shipment.DeliveryBatch
  alias FraytElixir.Shipment
  alias FraytElixir.Repo

  def render("index.json", %{batches: batches}) do
    %{response: render_many(batches, BatchView, "batch.json")}
  end

  def render("show.json", %{batch: batch}) do
    %{response: render_one(batch, BatchView, "batch.json")}
  end

  def render("batch.json", %{batch: batch}) do
    %DeliveryBatch{
      id: id,
      pickup_at: pickup_at,
      complete_by: complete_by,
      state: state,
      po: po,
      contract: contract,
      pickup_notes: pickup_notes,
      service_level: service_level,
      location: location,
      shipper: shipper,
      address: address,
      match_stops: match_stops,
      matches: matches
    } =
      batch =
      Repo.preload(batch,
        match_stops: [:destination_address, :recipient, :items],
        matches: [:origin_address, match_stops: :recipient, sender: []],
        location: [],
        shipper: [],
        address: [],
        state_transitions: []
      )

    transition = Shipment.find_transition(batch, state, :desc)

    %{
      id: id,
      pickup_at: pickup_at,
      complete_by: complete_by,
      pickup_notes: pickup_notes,
      contract: contract,
      state: state,
      po: po,
      service_level: service_level,
      location: render_one(location, LocationView, "location.json"),
      shipper: render_one(shipper, ShipperView, "shipper.json"),
      address: render_one(address, AddressView, "address.json"),
      match_stops: render_many(match_stops, MatchStopView, "match_stop.json"),
      matches: render_many(matches, MatchView, "match.json"),
      state_transition: render_one(transition, StateTransitionView, "state_transition.json")
    }
  end
end
