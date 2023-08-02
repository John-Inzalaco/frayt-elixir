defmodule FraytElixirWeb.API.Internal.MatchView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.ErrorView
  alias FraytElixirWeb.API.Internal.{MatchView, MarketView, ShipperView, ContractView}

  alias FraytElixirWeb.{
    MatchStopView,
    AddressView,
    DriverView,
    ChangesetView,
    MatchFeeView,
    ContactView,
    ETAView
  }

  alias FraytElixir.Shipment.{Address, Match, MatchStateTransition}
  alias FraytElixir.Shipment
  alias FraytElixir.Repo
  import FraytElixirWeb.DisplayFunctions

  def render("index.json", %{matches: matches, page_count: page_count}) do
    render("index.json", %{matches: matches})
    |> Map.put(:page_count, page_count)
  end

  def render("index.json", %{matches: matches}) do
    %{response: render_many(matches, MatchView, "match.json")}
  end

  def render("show.json", %{match: match}) do
    %{response: render_one(match, MatchView, "match.json")}
  end

  def render("maybe_matches.json", %{matches: matches}) do
    %{response: render_many(matches, MatchView, "maybe_match.json")}
  end

  def render("maybe_match.json", %{match: {:error, error}}) do
    ChangesetView.render("error.json", %{changeset: error})
  end

  def render("maybe_match.json", %{match: {:ok, %Match{} = match}}) do
    render_one(match, MatchView, "match.json")
  end

  def render("match.json", %{match: match}) do
    match =
      Repo.preload(match, [
        :origin_address,
        :coupon,
        :market,
        :fees,
        :contract,
        :shipper,
        :eta,
        preferred_driver: [:user],
        match_stops: [:items, :destination_address, :eta]
      ])

    {canceled_at, cancel_reason} =
      case Shipment.find_transition(match, :canceled) ||
             Shipment.find_transition(match, :admin_canceled) do
        %MatchStateTransition{notes: cancel_reason, inserted_at: canceled_at} ->
          {canceled_at, cancel_reason}

        _ ->
          {nil, nil}
      end

    coupon =
      case match.coupon do
        nil -> nil
        coupon -> %{percentage: coupon.percentage, code: coupon.code}
      end

    fees = Shipment.match_fees_for(match, :shipper)

    %{
      id: match.id,
      coupon: coupon,
      total_distance: match.total_distance,
      total_weight: match.total_weight,
      total_volume: match.total_volume,
      total_price: cents_to_dollars(match.amount_charged),
      price_discount: cents_to_dollars(match.price_discount),
      service_level: match.service_level,
      vehicle_class: match.vehicle_class,
      stops: render_many(match.match_stops, MatchStopView, "match_stop.json"),
      fees: render_many(fees, MatchFeeView, "shipper_match_fee.json"),
      dropoff_at: match.dropoff_at,
      pickup_at: match.pickup_at,
      scheduled: match.scheduled,
      pickup_notes: match.pickup_notes,
      bill_of_lading_required: match.bill_of_lading_required,
      origin_photo_required: match.origin_photo_required,
      po: match.po,
      shortcode: match.shortcode,
      identifier: match.identifier,
      state: match.state,
      shipper: render_one(match.shipper, ShipperView, "shipper.json"),
      sender: render_one(match.sender, ContactView, "contact.json"),
      market: render_one(match.market, MarketView, "shipper_market.json"),
      self_sender: match.self_sender,
      origin_address: render_one(match.origin_address, AddressView, "address.json"),
      inserted_at: match.inserted_at,
      picked_up_at: Shipment.match_transitioned_at(match, :picked_up),
      activated_at: Shipment.match_transitioned_at(match, :assigning_driver),
      accepted_at: Shipment.match_transitioned_at(match, :accepted),
      completed_at: Shipment.match_transitioned_at(match, :completed),
      canceled_at: canceled_at,
      cancel_reason: cancel_reason,
      contract: render_one(match.contract, ContractView, "contract.json"),
      bill_of_lading_photo: fetch_photo_url(match.id, match.bill_of_lading_photo),
      origin_photo: fetch_photo_url(match.id, match.origin_photo),
      driver: DriverView.render("driver.json", match),
      rating: match.rating,
      rating_reason: match.rating_reason,
      unload_method: match.unload_method,
      optimized_stops: match.optimized_stops,
      timezone: match.timezone,
      eta: render_one(match.eta, ETAView, "eta.json"),
      platform: match.platform,
      preferred_driver: DriverView.render("driver.json", %{driver: match.preferred_driver})
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

  def render("stripe_error.json", %Stripe.Error{} = error) do
    %{
      response: ErrorView.render("stripe_error.json", %{error: error})
    }
  end
end
