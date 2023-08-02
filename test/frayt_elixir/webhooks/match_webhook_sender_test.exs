defmodule FraytElixir.Webhooks.MatchWebhookSenderTest do
  use FraytElixir.DataCase
  alias FraytElixir.Drivers
  alias FraytElixirWeb.Test.FileHelper
  alias FraytElixir.{Shipment, Matches}
  alias FraytElixir.Shipment.{Match, MatchWorkflow}
  alias FraytElixir.Repo
  alias FraytElixir.Accounts.{Company, Location}
  alias Phoenix.PubSub
  alias FraytElixirWeb.API.Internal.MatchView
  alias FraytElixir.Webhooks.WebhookRequest
  alias FraytElixir.Webhooks.WebhookSupervisor
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  test "sending status to webhook" do
    company =
      insert(:company,
        webhook_url: "http://foo.com",
        webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
      )

    driver =
      insert(:driver_with_wallet,
        first_name: "Fred",
        last_name: "Flintstone",
        phone_number: "+1 5138675309"
      )

    %{match_stops: [stop]} =
      match =
      insert(:arrived_at_dropoff_match,
        driver: driver,
        shipper: build(:shipper, location: build(:location, company: company))
      )

    stop = %{stop | match: match}
    {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    Drivers.sign_stop(
      stop,
      %{contents: FileHelper.base64_image(), filename: "signature"},
      "Bob Jones"
    )

    assert_receive {:ok,
                    %HTTPoison.Response{
                      request_url: "http://foo.com",
                      body: %{
                        "driver" => %{
                          "first_name" => "Fred",
                          "last_name" => "F.",
                          "phone_number" => "+1 513-867-5309"
                        },
                        "stops" => [
                          %{
                            "signature_name" => "Bob Jones",
                            "signature_photo" => "some_url"
                          }
                        ],
                        "payload_id" => payload_id
                      },
                      headers: headers,
                      request: %{
                        options: [
                          {:recv_timeout, 15_000}
                        ]
                      }
                    }}

    assert payload_id

    assert Enum.count(headers) == 2

    assert headers
           |> Enum.find(fn {k, _v} -> k == "Authorization" end)
           |> elem(1)
           |> String.contains?("12345")

    assert Repo.all(WebhookRequest) |> Enum.count() == 1
  end

  test "sending status with a picked up match" do
    company =
      insert(:company,
        webhook_url: "http://foo.com",
        webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
      )

    driver =
      insert(:driver_with_wallet,
        current_location: build(:driver_location, geo_location: gaslight_point())
      )

    %{match_stops: [stop]} =
      match =
      insert(:arrived_at_pickup_match,
        driver: driver,
        shipper: build(:shipper, location: build(:location, company: company))
      )

    insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
    insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)
    {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    Drivers.picked_up(match, %{
      origin_photo: %{filename: "origin", binary: FileHelper.binary_image()}
    })

    assert_receive {:ok,
                    %HTTPoison.Response{
                      body: %{
                        "origin_photo" => "some_url",
                        "picked_up_at" => picked_up_at
                      }
                    }}

    assert String.contains?(picked_up_at, to_string(DateTime.utc_now().year))

    assert {:ok, _match} =
             Matches.update_and_authorize_match(match, %{
               stops: [
                 %{
                   destination_address: "641 Evangeline Rd Cincinnati OH 45240",
                   id: stop.id,
                   has_load_fee: false,
                   items:
                     Enum.map(stop.items, fn item ->
                       %{id: item.id, weight: 60, height: 10}
                     end)
                 }
               ]
             })

    assert_receive {:ok,
                    %HTTPoison.Response{
                      body: %{
                        "state" => "arrived_at_pickup"
                      }
                    }}
  end

  test "sending status with a delivered match" do
    company =
      insert(:company,
        webhook_url: "http://foo.com",
        webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
      )

    driver =
      insert(:driver_with_wallet,
        current_location: build(:driver_location, geo_location: gaslight_point())
      )

    %{match_stops: [stop]} =
      match =
      insert(:signed_match,
        amount_charged: 2000,
        driver: driver,
        shipper: build(:shipper, location: build(:location, company: company)),
        match_stops: [build(:signed_match_stop)]
      )

    insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
    insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

    stop = %{stop | match: match}
    {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    Drivers.deliver_stop(
      stop,
      %{
        "contents" => FileHelper.base64_image(),
        "filename" => "delivery_photo.jpg"
      }
    )

    assert_receive {:ok,
                    %HTTPoison.Response{
                      body: %{
                        "stops" => [
                          %{
                            "destination_photo" => "some_url"
                          }
                        ],
                        "completed_at" => delivered_at,
                        "state" => "completed"
                      }
                    }}

    assert String.contains?(delivered_at, to_string(DateTime.utc_now().year))
  end

  test "with no token" do
    company = insert(:company, webhook_url: "http://foo.com")

    %{match_stops: [stop]} =
      match =
      insert(:arrived_at_dropoff_match,
        shipper: build(:shipper, location: build(:location, company: company))
      )

    stop = %{stop | match: match}
    {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    Drivers.sign_stop(
      stop,
      %{contents: FileHelper.base64_image(), filename: "signature"},
      "Bob Jones"
    )

    assert_receive {:ok, %HTTPoison.Response{headers: headers}}

    assert Enum.count(headers) == 1
    assert Repo.all(WebhookRequest) |> Enum.count() == 1
  end

  test "with no webhook configured", %{pid: pid} do
    %{match_stops: [stop]} = match = insert(:arrived_at_dropoff_match)

    stop = %{stop | match: match}

    Drivers.sign_stop(
      stop,
      %{contents: FileHelper.base64_image(), filename: "signature"},
      "Bob Jones"
    )

    :timer.sleep(100)
    assert Process.info(pid)
  end

  test "with api_version 2.1 webhook config" do
    company =
      insert(:company,
        webhook_url: "http://foo.com",
        webhook_config: %{
          auth_header: "Authorization",
          auth_token: "Bearer 12345",
          api_version: :"2.1"
        }
      )

    driver = insert(:driver_with_wallet)

    match =
      insert(:assigning_driver_match,
        shipper: build(:shipper, location: build(:location, company: company))
      )

    {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
    {:ok, _} = Drivers.accept_match(match, driver)

    assert_receive {:ok, %HTTPoison.Response{body: %{"stops" => [%{"identifier" => _}]}}}
    assert Repo.all(WebhookRequest) |> Enum.count() == 1
  end

  test "with api_version 2.0 webhook config" do
    company =
      insert(:company,
        webhook_url: "http://foo.com",
        webhook_config: %{
          auth_header: "Authorization",
          auth_token: "Bearer 12345",
          api_version: :"2.0"
        }
      )

    driver = insert(:driver_with_wallet)

    match =
      insert(:assigning_driver_match,
        shipper: build(:shipper, location: build(:location, company: company))
      )

    {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
    {:ok, _} = Drivers.accept_match(match, driver)

    assert_receive {:ok, %HTTPoison.Response{body: %{"status" => "Accepted"}}}
    assert Repo.all(WebhookRequest) |> Enum.count() == 1
  end

  describe "subscribing to driver location updates" do
    test "driver accepted match is subscribed and receives updates", %{pid: _pid} do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match =
        insert(:assigning_driver_match,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      match2 =
        insert(:assigning_driver_match,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      {:ok, pid2} = WebhookSupervisor.start_match_webhook_sender(match2)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid2)
      driver = insert(:driver_with_wallet, first_name: "Fred", last_name: "Flintstone")
      {:ok, match} = Drivers.accept_match(match, driver)
      {:ok, match2} = Drivers.accept_match(match2, driver)
      Drivers.toggle_en_route(match)
      Drivers.toggle_en_route(match2)

      update_and_broadcast_location(driver, {84, 23})

      assert_receive {:ok, %HTTPoison.Response{body: body1}}
      assert_receive {:ok, %HTTPoison.Response{body: body2}}
      assert_receive {:ok, %HTTPoison.Response{body: body3}}
      assert_receive {:ok, %HTTPoison.Response{body: body4}}
      assert_receive {:ok, %HTTPoison.Response{body: body5}}
      assert_receive {:ok, %HTTPoison.Response{body: _body6}}

      # grab whichever message has a lat
      lat =
        [body1, body2, body3, body4, body5]
        |> Enum.map(fn body -> get_in(body, ["driver", "current_location", "lat"]) end)
        |> Enum.find(& &1)

      assert lat == 23

      assert [body1, body2, body3, body4]
             |> Enum.map(fn body -> get_in(body, ["driver", "last_name"]) end)
             |> Enum.all?(&(&1 == "F."))

      assert Repo.all(WebhookRequest) |> Enum.count() == 6
    end

    test "driver updates are not sent when match is not in progress", %{pid: _pid} do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match =
        insert(:assigning_driver_match,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver =
        insert(:driver_with_wallet,
          first_name: "Fred",
          last_name: "Flintstone",
          current_location: nil
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      assert {:ok, match} = Drivers.accept_match(match, driver)

      assert {:ok, match} = Repo.update(Match.changeset(match, %{state: :completed}))

      mst = insert(:match_state_transition, match: match, from: :accepted, to: :completed)

      PubSub.broadcast!(FraytElixir.PubSub, "match_state_transitions", {match, mst})
      PubSub.broadcast!(FraytElixir.PubSub, "match_state_transitions:#{match.id}", {match, mst})

      assert {:ok, _} = Drivers.update_current_location(driver, %Geo.Point{coordinates: {84, 23}})

      :timer.sleep(100)

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{"state" => "accepted", "driver" => %{"current_location" => nil}}
                      }},
                     300

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{"state" => "completed", "driver" => %{"current_location" => nil}}
                      }},
                     300

      refute_receive {:ok, %HTTPoison.Response{}}, 300
    end

    test "location updates for multiple matches with the same driver are sent", %{pid: _pid} do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match1 =
        insert(:assigning_driver_match,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      match2 =
        insert(:assigning_driver_match,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver =
        insert(:driver_with_wallet,
          first_name: "Fred",
          last_name: "Flintstone",
          current_location: nil
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match1)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      {:ok, pid2} = WebhookSupervisor.start_match_webhook_sender(match2)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid2)
      assert {:ok, %{id: match1_id}} = Drivers.accept_match(match1, driver)
      assert {:ok, %{id: match2_id} = match2} = Drivers.accept_match(match2, driver)

      driver = update_and_broadcast_location(driver, {84.0, 23.0})

      :timer.sleep(50)

      assert {:ok, match2} =
               Repo.update(Match.changeset(%{match2 | driver: driver}, %{state: :completed}))

      mst = insert(:match_state_transition, match: match2, from: :accepted, to: :completed)

      PubSub.broadcast!(FraytElixir.PubSub, "match_state_transitions", {match2, mst})

      PubSub.broadcast!(
        FraytElixir.PubSub,
        "match_state_transitions:#{match2.id}",
        {match2, mst}
      )

      :timer.sleep(50)

      update_and_broadcast_location(driver, {84.0, 27.0})

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match1_id,
                          "state" => "accepted",
                          "driver" => %{"current_location" => nil}
                        }
                      }},
                     1000

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match2_id,
                          "state" => "accepted",
                          "driver" => %{"current_location" => nil}
                        }
                      }},
                     1000

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match1_id,
                          "state" => "accepted",
                          "driver" => %{"current_location" => %{"lat" => 23.0, "lng" => 84.0}}
                        }
                      }},
                     1000

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match2_id,
                          "state" => "accepted",
                          "driver" => %{"current_location" => %{"lat" => 23.0, "lng" => 84.0}}
                        }
                      }},
                     1000

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match2_id,
                          "state" => "completed",
                          "driver" => %{"current_location" => %{"lat" => 23.0, "lng" => 84.0}}
                        }
                      }},
                     1000

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match1_id,
                          "state" => "accepted",
                          "driver" => %{"current_location" => %{"lat" => 27.0, "lng" => 84.0}}
                        }
                      }},
                     1000

      refute_receive {:ok, %HTTPoison.Response{body: %{"id" => ^match2_id}}},
                     1000
    end

    test "driver updates after match is delivered are not sent" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match =
        insert(:assigning_driver_match,
          amount_charged: 2000,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver =
        insert(:driver_with_wallet,
          first_name: "Fred",
          last_name: "Flintstone",
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      {:ok, match} = Drivers.accept_match(match, driver)
      {:ok, match} = Drivers.toggle_en_route(match)
      {:ok, match} = Drivers.arrived_at_pickup(match)

      origin_image = %{filename: "origin", binary: FileHelper.binary_image()}
      bill_of_lading_image = %{filename: "bill_of_lading", binary: FileHelper.binary_image()}

      {:ok, %{match_stops: [stop]} = match} =
        Drivers.picked_up(match, %{
          origin_photo: origin_image,
          bill_of_lading_photo: bill_of_lading_image
        })

      stop = %{stop | match: match}

      {:ok, %{match_stops: [stop]} = match} = Drivers.toggle_en_route(stop)

      stop = %{stop | match: match}

      {:ok, %{match_stops: [stop]} = match} = Drivers.arrived_at_stop(stop)

      stop = %{stop | match: match}

      {:ok, %{match_stops: [stop]} = match} =
        Drivers.sign_stop(stop, %{contents: "", filename: ""}, "")

      stop = %{stop | match: match}

      {:ok, _match, _nps_score_id} = Drivers.deliver_stop(stop)

      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{body: %{"state" => "completed"}}}

      assert {:ok, _} = Drivers.update_current_location(driver, %Geo.Point{coordinates: {84, 23}})

      assert Repo.all(WebhookRequest) |> Enum.count() == 9

      refute_received {:ok, %HTTPoison.Response{}}
    end

    test "driver updates after match is canceled by admin are not sent" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match =
        insert(:assigning_driver_match,
          amount_charged: 2000,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver =
        insert(:driver_with_wallet,
          first_name: "Fred",
          last_name: "Flintstone",
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      {:ok, match} = Drivers.accept_match(match, driver)
      {:ok, match} = Drivers.toggle_en_route(match)
      {:ok, match} = Drivers.arrived_at_pickup(match)

      {:ok, _match} = MatchWorkflow.admin_cancel_match(match)

      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{body: %{"state" => "admin_canceled"}}}

      assert {:ok, _} = Drivers.update_current_location(driver, %Geo.Point{coordinates: {84, 23}})

      assert Repo.all(WebhookRequest) |> Enum.count() == 4
      refute_receive {:ok, %HTTPoison.Response{}}, 200
    end

    test "driver updates after match is canceled by shipper are not sent" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match =
        insert(:assigning_driver_match,
          amount_charged: 2000,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver = insert(:driver_with_wallet, first_name: "Fred", last_name: "Flintstone")
      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      {:ok, match} = Drivers.accept_match(match, driver)
      {:ok, match} = Drivers.toggle_en_route(match)
      {:ok, _match} = Shipment.shipper_cancel_match(match)

      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{body: %{"state" => "canceled"}}}

      assert {:ok, _} = Drivers.update_current_location(driver, %Geo.Point{coordinates: {84, 23}})

      refute_receive {:ok, %HTTPoison.Response{}}, 200
      assert Repo.all(WebhookRequest) |> Enum.count() == 3
    end

    test "driver updates after match is canceled by driver are not sent" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      match =
        insert(:assigning_driver_match,
          amount_charged: 2000,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver = insert(:driver_with_wallet, first_name: "Fred", last_name: "Flintstone")
      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      {:ok, match} = Drivers.accept_match(match, driver)
      {:ok, _match} = MatchWorkflow.driver_cancel_match(match, "I died")
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{}}
      assert_receive {:ok, %HTTPoison.Response{body: %{"state" => "assigning_driver"}}}

      assert {:ok, _} = Drivers.update_current_location(driver, %Geo.Point{coordinates: {84, 23}})

      assert Repo.all(WebhookRequest) |> Enum.count() == 3
      refute_receive {:ok, %HTTPoison.Response{}}, 200
    end
  end

  describe "sending most recent driver location" do
    test "sends a location with an assigned driver" do
      company = insert(:company, webhook_url: "http://foo.com")

      match =
        insert(:assigning_driver_match,
          amount_charged: 2000,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      driver = insert(:driver_with_wallet)
      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      {:ok, _} = Drivers.update_current_location(driver, chris_house_point())

      {:ok, _} = Drivers.accept_match(match, driver)

      %Geo.Point{coordinates: {lng, lat}} = chris_house_point()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "driver_lat" => ^lat,
                          "driver_lng" => ^lng
                        }
                      }}
    end

    test "sends no lat lng with no driver" do
      %Company{locations: [%Location{shippers: [shipper]}]} =
        insert(:company_with_location, webhook_url: "http://foo.com")
        |> Repo.preload(locations: [:shippers])

      %Match{id: match_id} = match = insert(:pending_match, driver: nil, shipper: shipper)
      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      assert {:ok, _} = Matches.update_and_authorize_match(match)

      assert_receive {:ok, %HTTPoison.Response{body: %{"match" => ^match_id} = result}}

      refute Map.get(result, "driver_lat")
      refute Map.get(result, "driver_lng")
    end
  end

  describe "driver canceled match" do
    test "sends assigning_driver update but not canceled update" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      driver = insert(:driver_with_wallet)

      match =
        insert(:arrived_at_pickup_match,
          driver: driver,
          shipper: build(:shipper, location: build(:location, company: company)),
          slas: [
            build(:match_sla),
            build(:match_sla, type: :pickup),
            build(:match_sla, type: :pickup, driver_id: driver.id),
            build(:match_sla, type: :delivery),
            build(:match_sla, type: :delivery, driver_id: driver.id)
          ]
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      Drivers.cancel_match(match, "Some reason")

      assert_receive {:ok, %HTTPoison.Response{body: %{"state" => "driver_canceled"}}}
      assert_receive {:ok, %HTTPoison.Response{body: %{"state" => "assigning_driver"}}}
      assert Repo.all(WebhookRequest) |> Enum.count() == 2
    end
  end

  describe "process webhook requests on startup" do
    test "should process webhook requests of type match" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      driver =
        insert(:driver_with_wallet,
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      match =
        insert(:arrived_at_pickup_match,
          driver: driver,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      payload = MatchView.render("match.json", %{match: match})

      webhook_request =
        insert(:webhook_request, %{
          webhook_type: "match",
          payload: payload,
          company: company,
          record_id: match.id,
          state: "pending"
        })

      WebhookSupervisor.start_children()
      |> Enum.each(fn {:ok, pid} ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      end)

      match_id = match.id

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match_id,
                          "state" => "arrived_at_pickup"
                        }
                      }}

      :timer.sleep(1000)

      assert %{state: :completed} = Repo.get(WebhookRequest, webhook_request.id)
    end

    test "should save errors when processing webhook requests of type match_webhook on startup" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      driver =
        insert(:driver_with_wallet,
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      match =
        insert(:arrived_at_pickup_match,
          driver: driver,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      payload = MatchView.render("match.json", %{match: match})

      webhook_request =
        insert(:webhook_request, %{
          webhook_type: "match",
          payload: payload,
          company: company,
          record_id: match.id,
          state: "pending"
        })

      :ok = stop_supervised(WebhookSupervisor)
      start_failing_match_webhook_sender(self())

      WebhookSupervisor.start_children()
      |> Enum.each(fn {:ok, pid} ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      end)

      assert_receive {:error, _msg}
      :timer.sleep(1000)
      assert %{state: :failed} = Repo.get(WebhookRequest, webhook_request.id)
    end
  end

  defp update_and_broadcast_location(driver, coordinates) do
    {:ok, driver} = Drivers.update_current_location(driver, %Geo.Point{coordinates: coordinates})

    FraytElixirWeb.Endpoint.broadcast("driver_locations:#{driver.id}", "driver_location", %{
      driver.current_location
      | driver: driver
    })

    driver
  end
end
