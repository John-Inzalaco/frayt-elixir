defmodule FraytElixirWeb.API.Internal.ShipperControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Accounts.{Shipper, UserAgreement}

  alias FraytElixir.Repo

  import FraytElixirWeb.Test.LoginHelper

  import FraytElixir.Factory

  @invalid_attrs %{address: nil, agreement: nil, city: nil, company: nil, state: nil, zip: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create shipper" do
    test "renders shipper when data is valid", %{conn: conn} do
      %{id: document_id} =
        insert(:agreement_document,
          type: :eula,
          user_types: [:shipper],
          updated_at: ~N[2020-01-01 00:00:00]
        )

      frontend_data = %{
        "commercial" => false,
        "email" => "bob@jones.com",
        "first_name" => "Bob",
        "last_name" => "Jones",
        "company" => "Company, Inc",
        "job_title" => "Developer",
        "password" => "12345",
        "phone" => "1112223333",
        "referrer" => "Kroger",
        "monthly_shipments" => "11-25",
        "city" => "Hillsboro",
        "state" => "Ohio",
        "team_size" => "1-10",
        "start_shipping" => "now",
        "texting" => true,
        "api_integration" => true,
        "schedule_demo" => true,
        "agreements" => [
          %{
            "document_id" => document_id,
            "agreed" => true
          }
        ]
      }

      conn = post(conn, Routes.api_v2_shipper_path(conn, :create, ".1"), frontend_data)

      assert %{
               "token" => token,
               "shipper" => %{
                 "id" => shipper_id,
                 "phone" => "1112223333",
                 "referrer" => "Kroger",
                 "first_name" => "Bob",
                 "last_name" => "Jones",
                 "company" => "Company, Inc",
                 "texting" => true,
                 "pending_agreements" => []
               }
             } = json_response(conn, 201)["response"]

      assert {:ok, _claims} = FraytElixir.Guardian.decode_and_verify(token)

      assert %Shipper{user_id: user_id} = Repo.get(Shipper, shipper_id)

      assert %UserAgreement{document_id: ^document_id} =
               Repo.get_by(UserAgreement, user_id: user_id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.api_v2_shipper_path(conn, :create, ".1"), shipper: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "shipper adding shipper to company" do
    setup [:create_shipper, :login_as_company_admin_shipper]

    test "create shipper and approve them automatically", %{conn: conn, shipper: shipper} do
      conn =
        post(conn, Routes.api_v2_shipper_path(conn, :create, ".1"), %{
          "first_name" => "tess",
          "last_name" => "jgjgjg",
          "location_id" => shipper.location_id,
          "phone" => "9889888",
          "role" => "member",
          "user" => %{"email" => "jslk@sdf.sf"}
        })

      assert "approved" == json_response(conn, 200)["response"]["state"]
    end
  end

  describe "register shipper" do
    test "registers shipper without password", %{conn: conn} do
      frontend_data = %{
        "email" => "bob@jones.com",
        "first_name" => "Bob",
        "last_name" => "Jones",
        "company" => "Company, Inc",
        "phone" => "1112223333",
        "commercial" => "true"
      }

      conn = post(conn, Routes.api_v2_shipper_path(conn, :register, ".1"), frontend_data)

      assert %{
               "id" => shipper_id,
               "phone" => "1112223333",
               "referrer" => nil,
               "first_name" => "Bob",
               "last_name" => "Jones",
               "company" => "Company, Inc",
               "commercial" => true,
               "pending_agreements" => []
             } = json_response(conn, 201)["response"]

      assert %Shipper{} = Repo.get(Shipper, shipper_id)
    end
  end

  describe "show shipper" do
    test "shipper without company", %{conn: conn} do
      shipper = insert(:shipper, state: "approved")
      conn = add_token_for_shipper(conn, shipper)
      conn = get(conn, Routes.api_v2_shipper_path(conn, :show, ".1"))

      assert %{
               "email" => email,
               # is this valid?
               "state" => "approved",
               "pending_agreements" => []
             } = json_response(conn, 200)["response"]

      assert email == shipper.user.email
    end

    test "shipper with company", %{conn: conn} do
      shipper = insert(:shipper_with_location)
      conn = add_token_for_shipper(conn, shipper)
      conn = get(conn, Routes.api_v2_shipper_path(conn, :show, ".1"))

      assert %{
               "location" => %{
                 "id" => location_id,
                 "name" => location_name
               }
             } = json_response(conn, 200)["response"]

      assert location_name == shipper.location.location
      assert location_id == shipper.location.id
    end
  end

  describe "update shipper" do
    setup [:create_shipper, :login_as_shipper]

    test "renders shipper when data is valid", %{conn: conn, shipper: %Shipper{id: id} = shipper} do
      conn = add_token_for_shipper(conn, shipper)

      frontend_data = %{
        "address" => %{
          "address" => "123 main",
          "city" => "cincy",
          "state" => "oh",
          "zip" => "45454"
        },
        "email" => shipper.user.email,
        "firstName" => "Chris",
        "lastName" => "Traeger",
        "phone" => "(555) 555 - 5555"
      }

      conn = put(conn, Routes.api_v2_shipper_path(conn, :update, ".1"), frontend_data)

      assert %{
               "id" => ^id,
               "first_name" => first_name,
               "phone" => phone
             } = json_response(conn, 200)["response"]

      assert first_name == "Chris"
      assert phone == "5555555555"
    end

    test "sending one signal id", %{conn: conn, shipper: %Shipper{id: id}} do
      frontend_data = %{
        "one_signal_id" => "12345"
      }

      conn = put(conn, Routes.api_v2_shipper_path(conn, :update, ".1"), frontend_data)

      assert json_response(conn, 200)

      assert %Shipper{one_signal_id: "12345"} = Repo.get(Shipper, id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      frontend_data = %{
        "address" => %{
          "address" => "123 main",
          "city" => "cincy",
          "state" => "oh",
          "zip" => "45454"
        },
        "firstName" => "",
        "lastName" => "",
        "phone" => "5555555555"
      }

      conn = put(conn, Routes.api_v2_shipper_path(conn, :update, ".1"), frontend_data)
      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end
  end

  describe "unauthenticated update shipper" do
    setup [:create_shipper]

    test "renders 401", %{conn: conn} do
      frontend_data = %{
        "address" => "123 main",
        "city" => "cincy",
        "firstName" => "",
        "lastName" => "",
        "phone" => "5555555555",
        "state" => "oh",
        "zip" => "45454"
      }

      conn = put(conn, Routes.api_v2_shipper_path(conn, :update, ".1"), frontend_data)
      assert %{"code" => "unauthenticated"} = json_response(conn, 401)
    end
  end

  describe "index" do
    setup [:login_as_shipper]

    test "lists shippers", %{conn: conn, shipper: shipper} do
      location = insert(:location)

      shipper
      |> Ecto.Changeset.cast(
        %{
          role: :location_admin,
          location_id: location.id
        },
        [:role, :location_id]
      )
      |> Repo.update!()

      insert_list(5, :shipper, location: location)
      insert_list(5, :shipper)

      conn =
        get(conn, Routes.api_v2_shipper_path(conn, :index, ".1"), %{"per_page" => 10, "page" => 0})

      assert %{"data" => shippers, "page_count" => 1} = json_response(conn, 200)

      assert length(shippers) == 6
    end
  end

  defp create_shipper(_) do
    shipper = insert(:shipper)
    {:ok, shipper: shipper}
  end
end
