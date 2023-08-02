defmodule FraytElixirWeb.SessionHelperTest do
  use FraytElixirWeb.ConnCase, async: true

  import FraytElixirWeb.Test.LoginHelper
  import FraytElixirWeb.SessionHelper

  alias FraytElixir.Shipment.{Match, MatchStop}
  alias FraytElixir.Accounts.Shipper
  alias FraytElixir.Accounts.User
  alias FraytElixirWeb.Plugs.RequireAccessPipeline

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "authorize_shipper_for_api_account" do
    setup :create_shipper

    test "authorizes shipper", %{
      conn: conn,
      shipper: %{id: shipper_id} = shipper
    } do
      api_account =
        insert(:api_account,
          company:
            insert(:company,
              locations: [insert(:location, shippers: [shipper])]
            )
        )

      assert %{assigns: %{shipper: %Shipper{id: ^shipper_id}}} =
               conn
               |> add_token_for_api_account(api_account)
               |> RequireAccessPipeline.call([])
               |> authorize_api_account(%{})
               |> authorize_shipper_for_api_account(%{})
    end

    test "authorizes specific shipper", %{
      conn: conn,
      shipper: %{id: shipper_id, user: %{email: email}} = shipper
    } do
      api_account =
        insert(:api_account,
          company:
            insert(:company,
              locations: [
                insert(:location, shippers: [insert(:shipper, state: "approved"), shipper])
              ]
            )
        )

      assert %{assigns: %{shipper: %Shipper{id: ^shipper_id}}} =
               %{conn | params: Map.merge(conn.params, %{"shipper_email" => email})}
               |> add_token_for_api_account(api_account)
               |> RequireAccessPipeline.call([])
               |> authorize_api_account(%{})
               |> authorize_shipper_for_api_account(%{})
    end

    test "fails when doesn't belong to company", %{
      conn: conn,
      shipper: %{id: _shipper_id, user: %{email: email}}
    } do
      api_account =
        insert(:api_account,
          company:
            insert(:company,
              locations: [insert(:location, shippers: [insert(:shipper)])]
            )
        )

      assert %{assigns: %{code: :forbidden, layout: false}} =
               %{conn | params: Map.merge(conn.params, %{"shipper_email" => email})}
               |> add_token_for_api_account(api_account)
               |> RequireAccessPipeline.call([])
               |> authorize_api_account(%{})
               |> authorize_shipper_for_api_account(%{})
    end

    test "fails when shipper doesn't exist", %{conn: conn} do
      api_account =
        insert(:api_account,
          company:
            insert(:company,
              locations: [insert(:location, shippers: [insert(:shipper)])]
            )
        )

      assert %{assigns: %{code: :forbidden, layout: false}} =
               %{conn | params: Map.merge(conn.params, %{"shipper_email" => "fake@email.com"})}
               |> add_token_for_api_account(api_account)
               |> RequireAccessPipeline.call([])
               |> authorize_api_account(%{})
               |> authorize_shipper_for_api_account(%{})
    end

    test "fails when shipper is disabled", %{conn: conn} do
      shipper = insert(:shipper, state: "disabled")

      api_account =
        insert(:api_account,
          company:
            insert(:company,
              locations: [insert(:location, shippers: [shipper])]
            )
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> RequireAccessPipeline.call([])
        |> authorize_api_account(%{})

      assert %{assigns: %{code: :forbidden, layout: false}} =
               conn
               |> authorize_shipper_for_api_account(%{})

      assert %{assigns: %{code: :forbidden, layout: false}} =
               %{conn | params: Map.merge(conn.params, %{"shipper_email" => shipper.user.email})}
               |> authorize_shipper_for_api_account(%{})
    end

    test "fails when not logged in with api account", %{conn: conn} do
      assert %{assigns: %{code: :forbidden, layout: false}} =
               conn |> authorize_shipper_for_api_account(%{})
    end
  end

  describe "authorize_driver_match_stop" do
    test "valid match and stop assigns match stop", %{conn: conn} do
      %Match{
        id: match_id,
        driver: driver,
        match_stops: [%{id: stop_id} | _]
      } = insert(:picked_up_match)

      assert %Plug.Conn{assigns: %{match_stop: %MatchStop{id: ^stop_id}}} =
               conn
               |> Map.put(:params, %{
                 "match_id" => match_id,
                 "stop_id" => stop_id
               })
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> authorize_driver()
               |> authorize_driver_match()
               |> authorize_driver_match_stop()
    end

    test "stop belonging to other match returns forbidden", %{conn: conn} do
      %Match{
        id: match_id,
        driver: driver
      } = insert(:picked_up_match)

      stop = insert(:match_stop)

      assert %Plug.Conn{status: 403} =
               conn
               |> Map.put(:params, %{
                 "match_id" => match_id,
                 "stop_id" => stop.id
               })
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> authorize_driver()
               |> authorize_driver_match()
               |> authorize_driver_match_stop()
    end

    test "nonexistent stop found returns forbidden", %{conn: conn} do
      %Match{
        id: match_id,
        driver: driver
      } = insert(:picked_up_match)

      assert %Plug.Conn{status: 403} =
               conn
               |> Map.put(:params, %{
                 "match_id" => match_id,
                 "stop_id" => "fadjskfhalsdfhj"
               })
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> authorize_driver()
               |> authorize_driver_match()
               |> authorize_driver_match_stop()
    end
  end

  describe "authorize_match_stop_item" do
    test "authorizes match stop item", %{conn: conn} do
      %Match{
        id: match_id,
        driver: driver,
        match_stops: [%{id: stop_id, items: [%{id: item_id} | _]} | _]
      } = insert(:picked_up_match)

      assert %Plug.Conn{assigns: %{match_stop: %MatchStop{id: ^stop_id}}} =
               conn
               |> Map.put(:params, %{
                 "match_id" => match_id,
                 "stop_id" => stop_id,
                 "item_id" => item_id
               })
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> authorize_driver()
               |> authorize_driver_match()
               |> authorize_driver_match_stop()
               |> authorize_driver_match_stop_item()
    end
  end

  describe "authorize_match" do
    test "authorized shipper assigns match", %{conn: conn} do
      shipper = insert(:shipper)
      %Match{id: match_id} = insert(:match, shipper: shipper)

      assert %Plug.Conn{assigns: %{match: %Match{id: ^match_id}}} =
               conn
               |> Map.put(:params, %{"id" => match_id})
               |> add_token_for_shipper(shipper)
               |> RequireAccessPipeline.call([])
               |> maybe_authorize_shipper()
               |> authorize_match()
    end

    test "authorized shipper assigns shipperless match", %{conn: conn} do
      shipper = insert(:shipper)
      %Match{id: match_id} = insert(:match, shipper: nil)

      assert %Plug.Conn{assigns: %{match: %Match{id: ^match_id}}} =
               conn
               |> Map.put(:params, %{"id" => match_id})
               |> add_token_for_shipper(shipper)
               |> RequireAccessPipeline.call([])
               |> maybe_authorize_shipper()
               |> authorize_match()
    end

    test "authorized shipper who is not the matches shipper fails", %{conn: conn} do
      match_shipper = insert(:shipper)
      shipper = insert(:shipper)
      %Match{id: match_id} = insert(:match, shipper: match_shipper)

      assert %Plug.Conn{status: 403} =
               conn
               |> Map.put(:params, %{"id" => match_id})
               |> add_token_for_shipper(shipper)
               |> RequireAccessPipeline.call([])
               |> maybe_authorize_shipper()
               |> authorize_match()
    end

    test "unauthorized user assigns shipperless match", %{conn: conn} do
      %Match{id: match_id} = insert(:match, shipper: nil)

      assert %Plug.Conn{assigns: %{match: %Match{id: ^match_id}}} =
               conn
               |> Map.put(:params, %{"id" => match_id})
               |> maybe_authorize_shipper()
               |> authorize_match()
    end

    test "unauthorized user attempt on shippers match fails", %{conn: conn} do
      %Match{id: match_id} = insert(:match)

      assert %Plug.Conn{status: 403} =
               conn
               |> Map.put(:params, %{"id" => match_id})
               |> maybe_authorize_shipper()
               |> authorize_match()
    end
  end

  describe "maybe_authorize_shipper" do
    test "authorizes shipper", %{conn: conn} do
      shipper = %Shipper{id: shipper_id} = insert(:shipper)

      assert %Plug.Conn{
               assigns: %{
                 current_shipper: %Shipper{id: ^shipper_id},
                 current_shipper_id: ^shipper_id
               }
             } =
               conn
               |> add_token_for_shipper(shipper)
               |> RequireAccessPipeline.call([])
               |> maybe_authorize_shipper()
    end

    test "allows unauthorized user", %{conn: conn} do
      assert %Plug.Conn{assigns: %{current_shipper: nil, current_shipper_id: nil}} =
               conn
               |> maybe_authorize_shipper()
    end

    test "doesn't allow a user who is not a shipper", %{conn: conn} do
      user = insert(:user)

      assert %Plug.Conn{status: 403} =
               conn
               |> add_token_for_user(user)
               |> RequireAccessPipeline.call([])
               |> maybe_authorize_shipper()
    end
  end

  describe "get_current_shipper" do
    test "gets current shipper", %{conn: conn} do
      shipper = %Shipper{id: shipper_id} = insert(:shipper)

      assert %Shipper{id: ^shipper_id} =
               conn
               |> add_token_for_shipper(shipper)
               |> RequireAccessPipeline.call([])
               |> get_current_shipper()
    end

    test "returns nil when not logged in", %{conn: conn} do
      assert conn
             |> RequireAccessPipeline.call([])
             |> get_current_shipper() == nil
    end
  end

  describe "update_driver_location" do
    test "updates location when there is a driver", %{conn: conn} do
      %{id: driver_id} = driver = insert(:driver)

      assert %Plug.Conn{assigns: %{driver_location: location}} =
               conn
               |> Map.put(:params, %{
                 "location" => %{
                   "latitude" => 84,
                   "longitude" => 23
                 }
               })
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> authorize_driver()
               |> update_driver_location(%{})

      assert %{geo_location: %Geo.Point{coordinates: {23, 84}}, driver_id: ^driver_id} = location
    end

    test "sets location to nil with no location data", %{conn: conn} do
      driver = insert(:driver)

      assert %Plug.Conn{assigns: %{driver_location: nil}} =
               conn
               |> Map.put(:params, %{
                 "location" => nil
               })
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> authorize_driver()
               |> update_driver_location(%{})
    end

    test "sets location to nil when no driver", %{conn: conn} do
      assert %Plug.Conn{assigns: %{driver_location: nil}} =
               conn
               |> Map.put(:params, %{
                 "location" => %{
                   "latitude" => 84,
                   "longitude" => 23
                 }
               })
               |> update_driver_location(%{})
    end
  end

  describe "ensure_latest_version" do
    test "returns not found when the version is not the application's latest version", %{
      conn: conn
    } do
      assigns = %{
        version: "2"
      }

      assert %{status: 404} =
               Map.put(conn, :assigns, assigns)
               |> ensure_latest_version(%{})
    end

    test "returns nil status (request continues) when the version is the application's latest version",
         %{
           conn: conn
         } do
      assigns = %{
        version: Application.get_env(:frayt_elixir, :api_version)
      }

      assert %{status: nil} =
               Map.put(conn, :assigns, assigns)
               |> ensure_latest_version(%{})
    end
  end

  describe "user_has_role/2" do
    test "checks if user has role" do
      %{user: user} = admin = insert(:admin_user, role: :admin)

      assert user_has_role(admin, :admin)
      refute user_has_role(admin, :member)
      assert user_has_role(user, :admin)
      refute user_has_role(user, :member)
      refute user_has_role(nil, :member)
    end
  end

  describe "validate_driver_registration/2" do
    test "driver with no expired or rejected docs can update a match", %{conn: conn} do
      driver =
        insert(:driver,
          images: [
            build(:driver_document, type: :license, expires_at: nil)
          ]
        )

      assert %Plug.Conn{
               assigns: assigns
             } =
               conn
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> validate_driver_registration()

      refute Map.get(assigns, :code)
    end

    test "driver with license expired cannot update a match", %{conn: conn} do
      driver =
        insert(:driver,
          images: [
            build(:driver_document, type: :license, expires_at: "1980-01-01")
          ]
        )

      assert %Plug.Conn{
               assigns: %{
                 code: :forbidden,
                 message: message
               }
             } =
               conn
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> validate_driver_registration()

      assert message ==
               "You have expired, rejected, or missing documents. Please contact support to continue."
    end

    test "driver with insurance or registration expired cannot update a match", %{conn: conn} do
      driver =
        insert(:driver,
          vehicles: [
            build(:vehicle,
              images: [build(:vehicle_document, type: :registration, expires_at: "1980-01-01")]
            )
          ]
        )

      assert %Plug.Conn{
               assigns: %{
                 code: :forbidden,
                 message: message
               }
             } =
               conn
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> validate_driver_registration()

      assert message ==
               "You have expired, rejected, or missing documents. Please contact support to continue."

      driver =
        insert(:driver,
          vehicles: [
            build(:vehicle,
              images: [build(:vehicle_document, type: :insurance, expires_at: "1980-01-01")]
            )
          ]
        )

      assert %Plug.Conn{
               assigns: %{
                 code: :forbidden,
                 message: message
               }
             } =
               conn
               |> add_token_for_driver(driver)
               |> RequireAccessPipeline.call([])
               |> validate_driver_registration()

      assert message ==
               "You have expired, rejected, or missing documents. Please contact support to continue."
    end
  end

  describe "set_user/2" do
    test "adds current_user to assigns", %{conn: conn} do
      %{id: user_id} = user = insert(:user)

      assert %Plug.Conn{
               assigns: %{
                 current_user: %User{id: ^user_id}
               }
             } =
               conn
               |> add_token_for_user(user)
               |> RequireAccessPipeline.call([])
               |> set_user(%{})
    end

    test "sets current_user to nil for unauthorized user", %{conn: conn} do
      assert %Plug.Conn{
               assigns: %{
                 current_user: nil
               }
             } =
               conn
               |> RequireAccessPipeline.call([])
               |> set_user(%{})
    end
  end

  defp create_shipper(_params) do
    {:ok, shipper: insert(:shipper, state: "approved")}
  end
end
