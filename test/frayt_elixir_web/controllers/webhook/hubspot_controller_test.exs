defmodule FraytElixirWeb.Webhook.HubspotControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Accounts.Shipper
  alias FraytElixir.Repo

  @valid_json %{
    "attempt_number" => 0,
    "change_source" => "CRM",
    "event_id" => "100",
    "object_id" => 123,
    "occurred_at" => 1_619_042_518_451,
    "portal_id" => 19_652_860,
    "property_name" => "hubspot_owner_id",
    "property_value" => "contact_hubspot_owner",
    "subscription_id" => 1_035_158,
    "subscription_type" => "company.propertyChange"
  }

  @valid_request %{
    "api_key" => "valid_hubspot_webhook_api_key",
    "_json" => [@valid_json]
  }

  @invalid_request %{
    "api_key" => "valid_hubspot_webhook_api_key",
    "_json" => [
      Map.merge(@valid_json, %{
        "object_id" => 666
      })
    ]
  }

  @forbidden_request %{
    "_json" => [@valid_json]
  }

  describe "handle_webhook" do
    test "hubspot_owner_id updates sales rep on company", %{conn: conn} do
      %{id: sales_rep_id} =
        insert(:admin_user,
          role: "sales_rep",
          user: build(:user, email: "contact_hubspot_owner@frayt.com")
        )

      %{id: shipper_id} =
        insert(:shipper,
          sales_rep: build(:admin_user),
          user: build(:user, email: "queried_contact@frayt.com")
        )

      conn = post(conn, Routes.webhook_hubspot_path(conn, :handle_webhooks), @valid_request)

      assert %{
               "data" => %{
                 "message" => "Successfully saved data"
               }
             } = json_response(conn, 200)

      assert %Shipper{sales_rep_id: ^sales_rep_id} = Repo.get!(Shipper, shipper_id)
    end

    test "fails with nonexistent sales rep", %{conn: conn} do
      conn = post(conn, Routes.webhook_hubspot_path(conn, :handle_webhooks), @invalid_request)

      assert %{
               "data" => %{
                 "message" => "Failed to update 1 of 1 sales rep(s)"
               }
             } = json_response(conn, 422)
    end

    test "fails with bad authentication", %{conn: conn} do
      conn = post(conn, Routes.webhook_hubspot_path(conn, :handle_webhooks), @forbidden_request)

      assert %{
               "code" => "not_found",
               "message" => "Not found"
             } = json_response(conn, 404)
    end
  end
end
