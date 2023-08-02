defmodule FraytElixirWeb.Internal.V2x1.DriverMatchView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.Internal.V2x1.DriverMatchView

  alias FraytElixirWeb.{
    MatchStopView,
    MatchFeeView,
    AddressView,
    ContactView,
    MatchSLAView,
    ETAView
  }

  alias FraytElixir.Shipment.{Match, MatchStop}
  alias FraytElixir.Shipment
  alias FraytElixir.Accounts.{Shipper, Location, Company}
  alias FraytElixir.Drivers
  alias FraytElixir.Repo
  alias Ecto.Association.NotLoaded

  import FraytElixirWeb.DisplayFunctions

  def render("index.json", %{matches: matches} = params) do
    %{
      response: %{
        results: render_many(matches, DriverMatchView, "match.json"),
        cursor: 0,
        count: Enum.count(matches),
        remaining: 0,
        total_pages: Map.get(params, :total_pages, 1)
      }
    }
  end

  def render("show.json", %{driver_match: driver_match}) do
    %{response: render_one(driver_match, DriverMatchView, "match.json")}
  end

  def render("show.json", %{driver_match: driver_match, nps_score_id: nps_score_id}) do
    driver_match = Map.put(driver_match, :nps_score_id, nps_score_id)
    %{response: render_one(driver_match, DriverMatchView, "match.json")}
  end

  def render("match.json", %{driver_match: %{driver: %NotLoaded{}} = match}),
    do: preload_and_render(match, :driver)

  def render("match.json", %{driver_match: %{shipper: %NotLoaded{}} = match}),
    do: preload_and_render(match, shipper: [location: [:company]])

  def render("match.json", %{driver_match: %{fees: %NotLoaded{}} = match}),
    do: preload_and_render(match, :fees)

  def render("match.json", %{driver_match: %{slas: %NotLoaded{}} = match}),
    do: preload_and_render(match, :slas)

  def render("match.json", %{driver_match: %{origin_address: %NotLoaded{}} = match}),
    do: preload_and_render(match, :origin_address)

  def render("match.json", %{driver_match: %{eta: %NotLoaded{}} = match}),
    do: preload_and_render(match, :eta)

  def render("match.json", %{
        driver_match: %{match_stops: [%MatchStop{items: %NotLoaded{}}]} = match
      }),
      do: preload_and_render(match, match_stops: [:items])

  def render("match.json", %{
        driver_match:
          %Match{
            id: id,
            shortcode: shortcode,
            driver_id: driver_id,
            pickup_at: pickup_at,
            dropoff_at: dropoff_at,
            origin_photo_required: origin_photo_required,
            pickup_notes: pickup_notes,
            service_level: service_level,
            driver_total_pay: driver_total_pay,
            origin_photo: origin_photo,
            bill_of_lading_required: bill_of_lading_required,
            bill_of_lading_photo: bill_of_lading_photo,
            inserted_at: inserted_at,
            cancel_reason: cancel_reason,
            total_weight: total_weight,
            total_volume: total_volume,
            state: state,
            total_distance: distance,
            vehicle_class: vehicle_class_index,
            platform: platform,
            po: po,
            preferred_driver_id: preferred_driver_id,
            shipper: shipper,
            origin_address: origin_address,
            match_stops: match_stops,
            driver: driver,
            scheduled: scheduled,
            unload_method: unload_method,
            sender: sender,
            self_sender: self_sender,
            slas: slas,
            eta: eta,
            parking_spot_required: parking_spot_required
          } = match
      }) do
    driver_email = Drivers.get_driver_email(driver)
    slas = Enum.filter(slas, &(&1.driver_id == match.driver_id))

    %{
      "id" => id,
      "shortcode" => shortcode,
      "driver_id" => driver_id,
      "driver_email" => driver_email,
      "pickup_at" => pickup_at,
      "dropoff_at" => dropoff_at,
      "rating" => nil,
      "scheduled" => scheduled,
      "origin_photo_required" => origin_photo_required,
      "pickup_notes" => pickup_notes,
      "service_level" => service_level,
      "driver_total_pay" => cents_to_dollars(driver_total_pay),
      "origin_photo" => fetch_photo_url(id, origin_photo),
      "bill_of_lading_photo" => fetch_photo_url(id, bill_of_lading_photo),
      "bill_of_lading_required" => bill_of_lading_required,
      "completed_at" => Shipment.match_transitioned_at(match, :completed),
      "picked_up_at" => Shipment.match_transitioned_at(match, :picked_up),
      "accepted_at" => Shipment.match_transitioned_at(match, :accepted),
      "created_at" => inserted_at,
      "cancel_reason" => cancel_reason,
      "total_weight" => total_weight,
      "total_volume" => total_volume,
      "state" => state,
      "distance" => distance,
      "vehicle_class" => vehicle_class(vehicle_class_index),
      "vehicle_class_id" => vehicle_class_index,
      "unload_method" => unload_method,
      "platform" => platform,
      "po" => po,
      "preferred_driver_id" => preferred_driver_id,
      "shipper" => %{
        "name" => shipper_name(shipper),
        "phone" => shipper_phone(shipper),
        "company" => shipper_company(shipper)
      },
      "sender" => render_one(sender, ContactView, "contact.json"),
      "self_sender" => self_sender,
      "origin_address" => render_one(origin_address, AddressView, "address.json"),
      "stops" => render_many(match_stops, MatchStopView, "match_stop.json"),
      "slas" => render_many(slas, MatchSLAView, "match_sla.json"),
      "fees" =>
        match
        |> Shipment.match_fees_for(:driver)
        |> render_many(MatchFeeView, "driver_match_fee.json"),
      "eta" => render_one(eta, ETAView, "eta.json"),
      "nps_score_id" => Map.get(match, :nps_score, nil),
      "parking_spot_required" => parking_spot_required
    }
  end

  defp preload_and_render(match, field) do
    match = match |> Repo.preload(field)
    render("match.json", %{driver_match: match})
  end

  defp shipper_name(%Shipper{first_name: first_name, last_name: last_name}),
    do: "#{first_name} #{last_name}"

  defp shipper_name(_), do: nil

  defp shipper_phone(%Shipper{phone: phone}), do: phone
  defp shipper_phone(_), do: nil

  defp shipper_company(%Shipper{location: %Location{company: %Company{name: company_name}}}),
    do: company_name

  defp shipper_company(_), do: nil
end
