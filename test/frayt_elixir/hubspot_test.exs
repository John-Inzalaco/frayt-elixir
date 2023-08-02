defmodule FraytElixir.HubspotTest do
  use FraytElixir.DataCase

  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Hubspot
  alias FraytElixir.Accounts.{Company, AdminUser, Shipper}

  setup do
    FakeSlack.clear_messages()
  end

  describe "setup_account/1" do
    test "creates account" do
      assert {:ok,
              %Hubspot.Account{
                access_token: "super_duper_valid_access_token",
                refresh_token: "super_duper_valid_refresh_token",
                expires_at: expires_at,
                hubspot_id: 19_653_124,
                domain: "domain.hubspot.com"
              }} = Hubspot.setup_account("super_duper_valid_code")

      assert :gt == DateTime.compare(expires_at, DateTime.utc_now())
    end

    test "updates existing account" do
      %{id: account_id} =
        insert(:hubspot_account,
          access_token: "flashdfalsfd",
          refresh_token: "jdahsjfjgasd",
          expires_at: DateTime.utc_now() |> DateTime.add(-60_000),
          hubspot_id: 19_653_124
        )

      assert {:ok,
              %Hubspot.Account{
                id: ^account_id,
                access_token: "super_duper_valid_access_token",
                refresh_token: "super_duper_valid_refresh_token",
                expires_at: expires_at
              }} = Hubspot.setup_account("super_duper_valid_code")

      assert :gt == DateTime.compare(expires_at, DateTime.utc_now())
    end

    test "fails with bad code" do
      assert {:error, %{"status" => "BAD_AUTH_CODE"}} =
               Hubspot.setup_account("super_duper_invalid_code")
    end
  end

  describe "update_account_tokens/1" do
    test "creates account" do
      account =
        insert(:hubspot_account,
          access_token: "flashdfalsfd",
          refresh_token: "super_duper_valid_refresh_token_1",
          expires_at: DateTime.utc_now() |> DateTime.add(-60_000)
        )

      assert {:ok,
              %Hubspot.Account{
                access_token: "super_duper_valid_access_token",
                refresh_token: "super_duper_valid_refresh_token",
                expires_at: expires_at
              }} = Hubspot.update_account_tokens(account)

      assert :gt == DateTime.compare(expires_at, DateTime.utc_now())
    end

    test "fails with bad code" do
      account = insert(:hubspot_account, refresh_token: "super_duper_invalid_code")

      assert {:error, %{"status" => "BAD_AUTH_CODE"}} = Hubspot.update_account_tokens(account)
    end
  end

  describe "get_default_account/0" do
    test "returns the default account" do
      %{id: account_id} = insert(:hubspot_account)
      insert_list(3, :hubspot_account)
      assert %Hubspot.Account{id: ^account_id} = Hubspot.get_default_account()
    end

    test "returns nil when no accounts" do
      assert nil == Hubspot.get_default_account()
    end
  end

  describe "get_access_token/1" do
    test "gets access token" do
      %{access_token: access_token} = account = insert(:hubspot_account, access_token: "my_token")

      assert {:ok, ^access_token} = Hubspot.get_access_token(account)
    end

    test "gets new token when old one is about to expire" do
      %{access_token: access_token} =
        account =
        insert(:hubspot_account, expires_at: DateTime.utc_now(), access_token: "my_token")

      assert {:ok, new_token} = Hubspot.get_access_token(account)

      assert new_token !== access_token
    end

    test "returns error when invalid refresh token" do
      account =
        insert(:hubspot_account, refresh_token: "invalid token", expires_at: DateTime.utc_now())

      assert {:error, %{"status" => "BAD_AUTH_CODE"}} = Hubspot.get_access_token(account)
    end

    test "returns error when no account" do
      assert {:error, :invalid_account} = Hubspot.get_access_token(nil)
    end
  end

  describe "sync with hubspot" do
    @attrs %{
      commercial: false,
      email: "101example@email.com",
      first_name: "Bob",
      last_name: "Jones",
      company: "Company, Inc",
      job_title: "Developer",
      password: "12345",
      phone: "1112223333",
      referrer: "Kroger",
      monthly_shipments: "11-25",
      city: "Hillsboro",
      state: "Ohio",
      team_size: "1-10",
      start_shipping: "now",
      texting: true,
      api_integration: true,
      schedule_demo: true
    }

    test "sync_shipper/2 creates new contact" do
      %{id: shipper_id} = shipper = insert(:shipper)

      assert {:ok, %Shipper{id: ^shipper_id, hubspot_id: "found_contact", sales_rep_id: nil}} =
               Hubspot.sync_shipper(shipper, @attrs)
    end

    test "sync_shipper/2 links with existing contact and sets company sales rep" do
      %{id: sales_rep_id} =
        insert(:admin_user, user: build(:user, email: "hubspot_owner@frayt.com"))

      %{id: shipper_id} = shipper = insert(:shipper)

      assert {:ok,
              %Shipper{
                id: ^shipper_id,
                hubspot_id: "ownerless_contact",
                sales_rep_id: ^sales_rep_id
              }} = Hubspot.sync_shipper(shipper, %{@attrs | email: "404email@example.com"})
    end

    test "sync_shipper/2 links with existing contact and sets contact sales rep" do
      %{id: sales_rep_id} =
        insert(:admin_user, user: build(:user, email: "contact_hubspot_owner@frayt.com"))

      %{id: shipper_id} = shipper = insert(:shipper)

      assert {:ok,
              %Shipper{id: ^shipper_id, hubspot_id: "found_contact", sales_rep_id: ^sales_rep_id}} =
               Hubspot.sync_shipper(shipper, @attrs)
    end

    test "sync_shipper/2 links with existing contact and sets nil for no sales rep" do
      %{id: shipper_id} = shipper = insert(:shipper)

      assert {:ok, %Shipper{id: ^shipper_id, hubspot_id: "found_contact", sales_rep_id: nil}} =
               Hubspot.sync_shipper(shipper, @attrs)
    end

    test "find_or_create_contact_from_shipper/1 finds existing contact" do
      assert {:ok, %{"id" => "found_contact"}} =
               Hubspot.find_or_create_contact_from_shipper(@attrs)
    end

    test "find_or_create_contact_from_shipper/1 creates new contact when not existing" do
      assert {:ok, %{"id" => "new_contact"}} =
               Hubspot.find_or_create_contact_from_shipper(%{@attrs | email: "example@email.com"})
    end

    test "create_contact_from_shipper/1 creates creates new contact in hubspot" do
      assert {:ok, %{"id" => "new_contact"}} = Hubspot.create_contact_from_shipper(@attrs)
    end

    test "create_company/1 creates a company" do
      assert {:ok,
              %{
                "id" => "new_company",
                "properties" => %{
                  "city" => "Hillsboro",
                  "state" => "Ohio",
                  "name" => "Company, Inc",
                  "phone" => "1112223333",
                  "numberofemployees" => "10",
                  "monthly_shipments" => "11-25",
                  "start_shipping" => "now",
                  "api_integration" => true,
                  "schedule_demo" => true
                }
              }} = Hubspot.create_company(@attrs)
    end

    test "create_company/1 fails with invalid data" do
      assert {:error, 400,
              %{
                "category" => "VALIDATION_ERROR"
              }} =
               Hubspot.create_company(
                 @attrs
                 |> Map.put(:start_shipping, "invalid_answer")
               )
    end

    test "create_contact/1" do
      assert {:ok,
              %{
                "id" => "new_contact",
                "properties" => %{
                  "city" => "Hillsboro",
                  "state" => "Ohio",
                  "firstname" => "Bob",
                  "lastname" => "Jones",
                  "phone" => "1112223333",
                  "email" => "101example@email.com",
                  "referrer" => "Kroger"
                }
              }} = Hubspot.create_contact(@attrs)
    end
  end

  describe "update_last_match/2" do
    test "finds matching contact and sets last_match" do
      mst = insert(:match_state_transition, to: :assigning_driver)

      match =
        insert(:match,
          state_transitions: [mst],
          shipper: build(:shipper, user: build(:user, email: "101test@frayt.com"))
        )

      assert :ok == Hubspot.update_last_match(match, mst)
    end

    test "returns error when can't find contact" do
      mst = insert(:match_state_transition, to: :assigning_driver)

      match =
        insert(:match,
          state_transitions: [mst]
        )

      assert :error == Hubspot.update_last_match(match, mst)
    end
  end

  describe "sync_sales_rep/2" do
    test "updates companies sales rep" do
      %AdminUser{id: sales_rep_id} =
        insert(:admin_user, user: build(:user, email: "hubspot_owner@frayt.com"))

      %Company{id: company_id} =
        insert(:company,
          sales_rep: nil,
          locations: [
            insert(:location,
              shippers: [insert(:shipper, user: build(:user, email: "queried_contact@frayt.com"))]
            )
          ]
        )

      assert {:ok, %Company{id: ^company_id, sales_rep_id: ^sales_rep_id}} =
               Hubspot.sync_sales_rep(200, "hubspot_owner")
    end

    test "updates shippers sales rep when no company" do
      %AdminUser{id: sales_rep_id} =
        insert(:admin_user, user: build(:user, email: "hubspot_owner@frayt.com"))

      %Shipper{id: shipper_id} =
        insert(:shipper, sales_rep: nil, user: build(:user, email: "queried_contact@frayt.com"))

      assert {:ok, %Shipper{id: ^shipper_id, sales_rep_id: ^sales_rep_id}} =
               Hubspot.sync_sales_rep(200, "hubspot_owner")
    end

    test "updates shippers sales rep to nil" do
      %Shipper{id: shipper_id} =
        insert(:shipper,
          sales_rep: insert(:admin_user),
          user: build(:user, email: "queried_contact@frayt.com")
        )

      assert {:ok, %Shipper{id: ^shipper_id, sales_rep_id: nil}} =
               Hubspot.sync_sales_rep(200, nil)
    end

    test "fails on missing shipper" do
      assert {:error,
              "Failed to assign sales rep to Frayt. Unable to find shipper with email queried_contact@frayt.com"} =
               Hubspot.sync_sales_rep(200, "hubspot_owner")
    end

    test "fails on missing sales rep" do
      insert(:shipper, sales_rep: nil, user: build(:user, email: "queried_contact@frayt.com"))

      assert {:error,
              "Failed to assign sales rep to Frayt. Unable to find sales rep with email hubspot_owner@frayt.com"} =
               Hubspot.sync_sales_rep(200, "hubspot_owner")
    end

    test "fails on timeout" do
      assert {:error,
              "Failed to assign sales rep for Hubspot company 0. Request timed out. Please try again in a couple minutes."} =
               Hubspot.sync_sales_rep(0, "hubspot_owner")
    end
  end

  describe "get_sales_rep_id_by_hubspot_id/1" do
    test "returns sales rep" do
      %{id: sales_rep_id} =
        insert(:admin_user, user: build(:user, email: "hubspot_owner@frayt.com"))

      assert {:ok, ^sales_rep_id} = Hubspot.get_sales_rep_id_by_hubspot_id("hubspot_owner")
    end

    test "returns error when email not found" do
      assert {:error, :email_not_found, "hubspot_owner@frayt.com"} =
               Hubspot.get_sales_rep_id_by_hubspot_id("hubspot_owner")
    end

    test "returns error when hubspot account not found" do
      assert {:error, :not_found, 0} = Hubspot.get_sales_rep_id_by_hubspot_id(0)
    end

    test "returns nil when id is nil" do
      assert {:ok, nil} = Hubspot.get_sales_rep_id_by_hubspot_id(nil)
    end
  end
end
