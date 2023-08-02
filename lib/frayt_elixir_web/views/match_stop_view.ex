defmodule FraytElixirWeb.MatchStopView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.{
    AddressView,
    ContactView,
    MatchStopItemView,
    ChangesetView,
    StateTransitionView,
    ETAView,
    ErrorView
  }

  alias FraytElixir.Shipment.{Address, MatchStop}
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Repo
  alias FraytElixir.Shipment
  import FraytElixirWeb.DisplayFunctions

  def render("index.json", %{match_stops: match_stops}) do
    %{response: render_many(match_stops, MatchStopView, "match_stop.json")}
  end

  def render("show.json", %{match_stop: match_stop}) do
    %{response: render_one(match_stop, MatchStopView, "match_stop.json")}
  end

  def render("maybe_match_stops.json", %{match_stops: match_stops}) do
    %{response: render_many(match_stops, MatchStopView, "maybe_match_stop.json")}
  end

  def render("maybe_match_stop.json", %{match_stop: {:error, error}}) do
    ChangesetView.render("error.json", %{changeset: error})
  end

  def render("maybe_match_stop.json", %{match_stop: {:ok, %MatchStop{} = match_stop}}) do
    render_one(match_stop, MatchStopView, "match_stop.json")
  end

  def render("match_stop.json", %{match_stop: %MatchStop{items: %NotLoaded{}} = match_stop}) do
    match_stop = match_stop |> Repo.preload([:items, :destination_address])
    render("match_stop.json", %{match_stop: match_stop})
  end

  def render("match_stop.json", %{
        match_stop: %MatchStop{destination_address: %NotLoaded{}} = match_stop
      }) do
    match_stop = match_stop |> Repo.preload([:items, :destination_address])
    render("match_stop.json", %{match_stop: match_stop})
  end

  def render("match_stop.json", %{
        match_stop: %MatchStop{eta: %NotLoaded{}} = match_stop
      }) do
    match_stop = match_stop |> Repo.preload(:eta)
    render("match_stop.json", %{match_stop: match_stop})
  end

  def render("match_stop.json", %{match_stop: stop}) do
    %MatchStop{
      id: id,
      identifier: identifier,
      state: state,
      index: index,
      recipient: recipient,
      self_recipient: self_recipient,
      delivery_notes: delivery_notes,
      destination_address: address,
      signature_photo: photo,
      signature_type: signature_type,
      signature_instructions: signature_instructions,
      signature_name: signature_name,
      destination_photo: destination_photo,
      destination_photo_required: destination_photo_required,
      has_load_fee: has_load_fee,
      needs_pallet_jack: needs_pallet_jack,
      tip_price: tip_price,
      dropoff_by: dropoff_by,
      items: items,
      po: po,
      signature_required: signature_required,
      eta: eta
    } = stop = Repo.preload(stop, :state_transitions)

    transition = Shipment.find_transition(stop, state, :desc)

    %{
      state: state,
      index: index,
      recipient: render_one(recipient, ContactView, "contact.json"),
      self_recipient: self_recipient,
      delivery_notes: delivery_notes,
      destination_address: render_one(address, AddressView, "address.json"),
      signature_type: signature_type,
      signature_instructions: signature_instructions,
      signature_photo: fetch_photo_url(id, photo),
      signature_name: signature_name,
      destination_photo: fetch_photo_url(id, destination_photo),
      destination_photo_required: destination_photo_required,
      has_load_fee: has_load_fee,
      needs_pallet_jack: needs_pallet_jack,
      driver_tip: cents_to_dollars(tip_price),
      id: id,
      identifier: identifier,
      dropoff_by: dropoff_by,
      items: render_many(items, MatchStopItemView, "match_stop_item.json"),
      po: po,
      state_transition: render_one(transition, StateTransitionView, "state_transition.json"),
      signature_required: signature_required,
      eta: render_one(eta, ETAView, "eta.json")
    }
  end

  def render("status.json", %{
        status:
          %{
            match: _,
            stage: _,
            message: _,
            status: _,
            identifier: _,
            receiver_name: _,
            receiver_signature: _
          } = status
      }) do
    status
  end

  def render(
        "address.json",
        %Address{
          geo_location: %Geo.Point{
            coordinates: {lng, lat}
          }
        } = address
      ) do
    %{
      address: address.address,
      lat: lat,
      lng: lng
    }
  end

  def render("address.json", _), do: nil

  def render("error.json", %{changeset: changeset}) do
    %{
      response: ErrorView.render("changeset_error.json", %{changeset: changeset})
    }
  end
end
