defmodule FraytElixir.AccountsTest do
  use FraytElixir.DataCase

  alias FraytElixir.Accounts
  alias FraytElixir.Email

  alias FraytElixir.Accounts.{
    User,
    Shipper,
    Schedule,
    Location,
    AdminUser,
    ApiAccount,
    Company,
    AgreementDocument,
    UserAgreement
  }

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Drivers
  alias FraytElixir.Notifications.DriverNotification
  alias Ecto.Changeset

  import FraytElixir.Factory

  use Bamboo.Test

  describe "users" do
    alias FraytElixir.Accounts.User

    @valid_attrs %{email: "some_email@test.com", password: "mysecretpasswordissohardtoguess"}
    @update_attrs %{email: "some_updated_email@test.com"}
    @invalid_attrs %{email: nil, hashed_password: nil}

    test "list_users/0 returns all users" do
      user = insert(:user)
      assert Enum.map(Accounts.list_users(), & &1.id) == [user.id]
    end

    test "get_user!/1 returns the user with given id" do
      user = insert(:user)
      found_user = Accounts.get_user!(user.id)
      assert user.email == found_user.email
    end

    test "get_user/1 returns an {:ok, user} with given id" do
      user = insert(:user)
      assert {:ok, found_user} = Accounts.get_user(user.id)
      assert user.email == found_user.email
    end

    test "get_user/1 returns {:error, _} with invalid id" do
      shipper = insert(:shipper)

      assert {:error, _} = Accounts.get_user(shipper.id)
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
      assert user.email == "some_email@test.com"
      assert String.length(user.hashed_password) > 0
    end

    test "create_user/1 doesn't allow create same user with different email case" do
      valid_attrs = %{@valid_attrs | email: "lower_email@test.com"}
      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.email == "lower_email@test.com"
      assert String.length(user.hashed_password) > 0

      valid_attrs = %{@valid_attrs | email: "LOWER_email@test.com"}
      assert {:error, %{errors: [error | _]}} = Accounts.create_user(valid_attrs)

      expected_error =
        {:email,
         {"has already been taken.", [constraint: :unique, constraint_name: "users_email_index"]}}

      assert expected_error == error
    end

    test "create_user/1 with uppercase email creates a user with a upper case email" do
      attrs = Map.merge(@valid_attrs, %{email: "JOHN@Doe.COm"})
      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.email == "JOHN@doe.com"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = insert(:user)
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.email == "some_updated_email@test.com"
    end

    test "update_user/2 with uppercase email updates a user with a uppercase email" do
      user = insert(:user)
      attrs = Map.merge(@update_attrs, %{email: "JOHN@Doe.COm"})
      assert {:ok, %User{} = user} = Accounts.update_user(user, attrs)
      assert user.email == "JOHN@doe.com"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = insert(:user)
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      found_user = Accounts.get_user!(user.id)
      assert user.email == found_user.email
    end

    test "delete_user/1 deletes the user" do
      user = insert(:user)
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = insert(:user)
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end

    test "verify_code verifies correct code" do
      %{email: email, password_reset_code: password_reset_code} = insert(:unregistered_user)

      assert {:ok, %User{id: id, email: ^email, password_reset_code: nil}} =
               Accounts.verify_code(email, password_reset_code)

      fetched_user = Accounts.get_user!(id)
      refute fetched_user.password_reset_code
    end

    test "verify_code does not verify incorrect code" do
      user = insert(:unregistered_user)
      assert {:error, _} = Accounts.verify_code(user.email, "GARBAGE")
      fetched_user = Accounts.get_user!(user.id)
      assert fetched_user.password_reset_code
    end

    test "authenticate authenticates with correct password" do
      %{user: %{email: email}} = insert(:shipper)

      assert {:ok, %User{email: ^email}} = Accounts.authenticate(email, "password", :shipper)
    end

    test "authenticate is not case-sensitive for the email field" do
      %{user: %{email: email}} = insert(:shipper)
      upper_email = String.upcase(email)

      assert email != upper_email

      assert {:ok, %User{email: ^email}} =
               Accounts.authenticate(upper_email, "password", :shipper)
    end

    test "authenticate is case-sensitive for the password field" do
      %{user: %{email: email}} = insert(:shipper)
      upper_email = String.upcase(email)

      assert email != upper_email

      assert {:error, :invalid_credentials} =
               Accounts.authenticate(upper_email, "PASSWORD", :shipper)
    end

    test "authenticate authenticates with uppercase email" do
      insert(:shipper, user: build(:user, email: "john@doe.com"))

      assert {:ok, %User{}} = Accounts.authenticate("JOHN@Doe.Com", "password", :shipper)
    end

    test "authenticate with bad password returns an error" do
      %{user: user} = insert(:shipper)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate(user.email, "garbage", :shipper)
    end

    test "authenticate with no password returns an error" do
      %{user: user} = insert(:shipper)

      assert {:error, :invalid_credentials} = Accounts.authenticate(user.email, nil, :shipper)
    end

    test "authenticate with bad email returns an error" do
      insert(:shipper)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate("garbage", "more garbage", :shipper)
    end

    test "authenticate with no email returns an error" do
      insert(:shipper, user: build(:user, email: nil))

      assert {:error, :invalid_credentials} = Accounts.authenticate(nil, "more garbage", :shipper)
    end

    test "authenticate returns an error if user is a disabled admin user" do
      admin = insert(:admin_user, disabled: true, user: build(:user))

      assert {:error, :disabled} = Accounts.authenticate(admin.user.email, "password", :admin)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate(admin.user.email, "garbage", :admin)
    end

    test "authenticate authenticates if user is a nondisabled admin user" do
      %AdminUser{user: %User{email: email}} =
        insert(:admin_user, disabled: false, user: build(:user))

      assert {:ok, %User{email: ^email}} = Accounts.authenticate(email, "password", :admin)
    end

    test "authenticate clears password reset code for admin users" do
      %AdminUser{user: %User{email: email, password_reset_code: reset_code}} =
        insert(:admin_user, disabled: false, user: build(:user, password_reset_code: "ABC123"))

      assert {:ok, %User{email: ^email, password_reset_code: nil}} =
               Accounts.authenticate(email, reset_code, :admin)
    end

    test "authenticate returns an error if user is a disabled shipper user" do
      shipper = insert(:shipper, state: "disabled", user: build(:user))

      assert {:error, :disabled} = Accounts.authenticate(shipper.user.email, "password", :shipper)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate(shipper.user.email, "garbage", :shipper)
    end

    test "authenticate returns an error if user is not associated with proper user type" do
      shipper = insert(:shipper, user: build(:user))

      assert {:error, :invalid_user} =
               Accounts.authenticate(shipper.user.email, "password", :admin)
    end

    test "authenticate authenticates if user is a nondisabled shipper user" do
      %Shipper{user: %User{email: email}} =
        insert(:shipper, state: "approved", user: build(:user))

      assert {:ok, %User{email: ^email}} = Accounts.authenticate(email, "password", :shipper)
    end

    test "authenticate_client_secret/2 authenticates with correct client and secret" do
      %{client_id: client_id, secret: secret, id: api_account_id} =
        insert(:api_account_with_company)

      assert {:ok, %ApiAccount{id: ^api_account_id}} =
               Accounts.authenticate_client_secret(client_id, secret)
    end

    test "authenticate_client_secret/2 with bad client_id returns an error" do
      %{secret: secret} = insert(:api_account_with_company)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_client_secret("foobar", secret)
    end

    test "authenticate_client_secret/2 with bad secret returns an error" do
      %{client_id: client_id} = insert(:api_account_with_company)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_client_secret(client_id, "foobar")
    end

    test "check_password authenticates with correct password" do
      user = %{email: email} = insert(:user)

      assert {:ok, %User{email: ^email}} = Accounts.check_password(user, "password")
    end

    test "check_password with bad password returns an error" do
      user = insert(:user)
      assert {:error, :invalid_password} = Accounts.check_password(user, "garbage")
    end

    test "check_password with no user returns an error" do
      insert(:user)
      assert {:error, :invalid_user_identifier} = Accounts.check_password(nil, "password")
    end

    test "check_password with no password returns an error" do
      user = insert(:user)
      assert {:error, :invalid_password} = Accounts.check_password(user, nil)
    end

    test "check_password authenticates with password_reset_code" do
      user = %{email: email} = insert(:user, password_reset_code: "code")
      assert {:ok, %User{email: ^email}} = Accounts.check_password(user, "code")
    end

    test "check_password with no password and password_reset_code returns an error" do
      user = insert(:user, password_reset_code: "code")
      assert {:error, :invalid_password} = Accounts.check_password(user, nil)
    end
  end

  test "get_api_account_by_client_id" do
    %ApiAccount{id: api_account_id, client_id: client_id} = insert(:api_account_with_company)

    assert %ApiAccount{id: ^api_account_id} = Accounts.get_api_account_by_client_id(client_id)
  end

  describe "create_api_account" do
    test "creates account" do
      company = insert(:company)

      assert {:ok, %ApiAccount{client_id: client_id, secret: secret}} =
               Accounts.create_api_account(company)

      assert client_id
      assert secret
    end

    test "requires company" do
      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [company: {_, [validation: :required]}]
              }} = Accounts.create_api_account(nil)
    end
  end

  describe "delete_api_account" do
    test "deletes account" do
      api_account = insert(:api_account)

      assert {:ok, %ApiAccount{}} = Accounts.delete_api_account(api_account)
    end
  end

  describe "shippers" do
    alias FraytElixir.Accounts.Shipper

    @valid_attrs %{
      first_name: "John",
      last_name: "Smith",
      phone: "1234567890",
      address: %{
        address: "some address",
        city: "some city",
        state: "some state",
        zip: "some zip"
      },
      agreement: true,
      company: "some company",
      email: "some@email.com",
      password: "secretpassword",
      role: "location_admin",
      agreements: []
    }
    @update_attrs %{
      address: %{
        address: "some updated address",
        city: "some updated city",
        state: "some updated state",
        zip: "some updated zip"
      },
      agreement: false,
      company: "some updated company"
    }
    @invalid_attrs %{address: nil, agreement: nil, city: nil, company: nil, state: nil, zip: nil}

    test "list_shippers/0 returns all shippers" do
      shipper = insert(:shipper)
      assert Accounts.list_shippers() |> Enum.map(& &1.id) == [shipper.id]
    end

    test "get_shipper!/1 returns the shipper with given id" do
      %{address: shipper_address} = shipper = insert(:shipper)
      %{address: fetched_shipper_address} = Accounts.get_shipper!(shipper.id)
      assert shipper_address == fetched_shipper_address
    end

    test "new_shipper?/1" do
      shipper = insert(:shipper)
      shipper2 = insert(:shipper)
      insert_list(3, :match, state: :en_route_to_pickup, shipper: shipper)
      insert(:match, state: :charged, shipper: shipper2)
      insert(:match, state: :completed, shipper: shipper)

      assert Accounts.new_shipper?(shipper.id)
      refute Accounts.new_shipper?(shipper2.id)
    end

    test "create_shipper/1 with valid data creates a shipper" do
      assert {:ok, %Shipper{address: address} = shipper} = Accounts.create_shipper(@valid_attrs)
      assert address.address == "some address"
      assert address.city == "some city"
      assert address.state == "some state"
      assert address.zip == "some zip"
      assert shipper.agreement == true
      assert shipper.company == "some company"
      assert shipper.user_id != nil
      assert shipper.role == :location_admin
    end

    test "create_shipper/1 accepts agreements" do
      %{id: document_id, support_documents: [%{id: support_document_id}]} =
        insert(:agreement_document,
          support_documents: [build(:agreement_document, type: :delivery_agreement)]
        )

      assert {:ok,
              %Shipper{
                user: %User{
                  agreements: [
                    %UserAgreement{
                      document_id: ^document_id,
                      agreed: true,
                      updated_at: ~N[2020-01-01 00:00:00]
                    },
                    %UserAgreement{
                      document_id: ^support_document_id,
                      agreed: true,
                      updated_at: ~N[2020-01-01 00:00:00]
                    }
                  ]
                }
              }} =
               Accounts.create_shipper(%{
                 @valid_attrs
                 | agreements: [
                     %{
                       document_id: document_id,
                       agreed: true,
                       updated_at: ~N[2020-01-01 00:00:00]
                     }
                   ]
               })
    end

    test "create_shipper/1 fails on rejected agreements" do
      %{id: document_id} = insert(:agreement_document)

      assert {:error,
              %Changeset{
                changes: %{user: %{changes: %{agreements: [%{errors: agreement_errors}]}}}
              }} =
               Accounts.create_shipper(%{
                 @valid_attrs
                 | agreements: [
                     %{
                       document_id: document_id,
                       agreed: false,
                       updated_at: ~N[2020-01-01 00:00:00]
                     }
                   ]
               })

      assert [
               agreed: {"you must accept agreements to continue", [validation: :has_agreed]}
             ] = agreement_errors
    end

    test "create_shipper/1 with invalid data returns error changeset" do
      assert {:error, _} = Accounts.create_shipper(@invalid_attrs)
    end

    test "create_shipper/1 with valid data and a user with email and no password creates a shipper" do
      assert {:ok, %Shipper{address: address} = shipper} =
               Accounts.create_shipper(%{
                 first_name: "First",
                 last_name: "Name",
                 user: %{email: "some@email.com"},
                 address: %{
                   address: "123 Some Pl",
                   city: "Cincinnati",
                   state: "Ohio",
                   state_code: "OH",
                   zip: "45202"
                 },
                 phone: "234-345-4567"
               })

      assert address.address == "123 Some Pl"
      assert address.city == "Cincinnati"
      assert address.state == "Ohio"
      assert address.state_code == "OH"
      assert address.zip == "45202"
      assert shipper.first_name == "First"
      assert shipper.last_name == "Name"
      assert shipper.phone == "2343454567"
      assert shipper.user.email == "some@email.com"
      assert shipper.user.password_reset_code != nil
      assert shipper.user_id != nil
    end

    test "create_shipper/1 for an invited personal account does not send a slack notification" do
      FakeSlack.clear_messages()

      assert {:ok, %Shipper{}} =
               Accounts.create_shipper(%{
                 first_name: "First",
                 last_name: "Name",
                 user: %{email: "some@email.com"},
                 address: %{
                   address: "123 Some Pl",
                   city: "Cincinnati",
                   state: "OH",
                   zip: "45202"
                 },
                 phone: "234-345-4567",
                 commercial: false
               })

      assert [] = FakeSlack.get_messages()
    end

    test "create_shipper/1 for a business account does send a slack notification" do
      FakeSlack.clear_messages()

      assert {:ok, %Shipper{} = shipper} =
               Accounts.create_shipper(%{
                 first_name: "First",
                 last_name: "Name",
                 email: "some@email.com",
                 password: "P@ssw0rd",
                 address: %{
                   address: "123 Some Pl",
                   city: "Cincinnati",
                   state: "OH",
                   zip: "45202"
                 },
                 phone: "234-345-4567",
                 commercial: true,
                 company: "Bob's Burgers",
                 agreements: []
               })

      :timer.sleep(100)

      assert [{_, message}] = FakeSlack.get_messages("#test-shippers")

      assert message =~ "business"
      assert message =~ shipper.company
      assert message =~ "(234)345-4567"
      assert message =~ "https://app.hubspot.com/contacts/6023447/contact/new_contact"
      assert message =~ "no assigned sales rep"
    end

    test "create_shipper/1 for a business account and sales rep send slack notification" do
      FakeSlack.clear_messages()

      insert(:admin_user, user: build(:user, email: "contact_hubspot_owner@frayt.com"))

      assert {:ok, %Shipper{}} =
               Accounts.create_shipper(%{
                 first_name: "First",
                 last_name: "Name",
                 email: "some@email.com",
                 password: "P@ssw0rd",
                 address: %{
                   address: "123 Some Pl",
                   city: "Cincinnati",
                   state: "OH",
                   zip: "45202"
                 },
                 phone: "234-345-4567",
                 commercial: true,
                 company: "Bob's Burgers",
                 agreements: []
               })

      :timer.sleep(100)

      assert [{_, message}] = FakeSlack.get_messages("#test-shippers")

      assert message =~ "hubspot_owner@frayt.com"
    end

    test "create_shipper/1 for a personal account does not send a slack notification" do
      FakeSlack.clear_messages()

      assert {:ok, %Shipper{}} =
               Accounts.create_shipper(%{
                 first_name: "First",
                 last_name: "Name",
                 email: "some@email.com",
                 password: "P@ssw0rd",
                 address: %{
                   address: "123 Some Pl",
                   city: "Cincinnati",
                   state: "OH",
                   zip: "45202"
                 },
                 phone: "234-345-4567",
                 commercial: false,
                 agreements: []
               })

      :timer.sleep(100)

      assert [] = FakeSlack.get_messages("#test-shippers")
    end

    test "create_shipper/1 with invalid data and a user with email and no password returns error changeset" do
      assert {:error, _} =
               Accounts.create_shipper(%{
                 first_name: "First",
                 last_name: nil,
                 user: %{email: "some@email.com"},
                 address: "123 Some Pl",
                 city: "Cincinnati",
                 state: "OH",
                 zip: "45202",
                 phone: nil
               })
    end

    test "update_shipper_stripe with valid data updates the shipper" do
      shipper = insert(:shipper)

      stripe_customer_id = "cus_testid"

      assert {:ok, %Shipper{stripe_customer_id: ^stripe_customer_id}} =
               Accounts.update_shipper_stripe(shipper, %{stripe_customer_id: stripe_customer_id})
    end

    test "update_shipper_stripe fails with no customer_id" do
      shipper = insert(:shipper)

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_shipper_stripe(shipper, %{stripe_customer_id: nil})
    end

    test "update_shipper/2 with valid data updates the shipper" do
      shipper = insert(:shipper)

      assert {:ok, %Shipper{address: address} = shipper} =
               Accounts.update_shipper(shipper, @update_attrs)

      assert address.address == "some updated address"
      assert address.city == "some updated city"
      assert address.state == "some updated state"
      assert address.zip == "some updated zip"
      assert shipper.agreement == false
      assert shipper.company == "some updated company"
    end

    test "update_shipper/2 with invalid data returns error changeset" do
      shipper = insert(:shipper)
      assert {:error, %Ecto.Changeset{}} = Accounts.update_shipper(shipper, @invalid_attrs)
      fetched_shipper = Accounts.get_shipper!(shipper.id)
      assert shipper.address == fetched_shipper.address
    end

    test "update_shipper/2 with user and valid data updates the shipper" do
      shipper = insert(:shipper)

      assert {:ok, %Shipper{} = shipper} =
               Accounts.update_shipper(shipper, %{
                 first_name: "New",
                 user: %{id: shipper.user.id, email: "another@email.com"}
               })

      assert shipper.first_name == "New"
      assert shipper.user.email == "another@email.com"
    end

    test "update_shipper/2 with user and invalid data returns error changeset" do
      shipper = insert(:shipper)

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_shipper(shipper, %{
                 first_name: "",
                 user: %{id: shipper.user.id, email: ""}
               })

      fetched_shipper = Accounts.get_shipper!(shipper.id)
      assert shipper.first_name == fetched_shipper.first_name
    end

    test "update_shipper/1 can remove a shipper from a company" do
      company = insert(:company, name: "Some Company")
      location = insert(:location, location: "Downtown", company: company)
      shipper = insert(:shipper, company: company.name, location: location, user: build(:user))

      location_users =
        Accounts.get_location!(location.id).shippers
        |> Enum.map(& &1.id)

      assert location_users == [shipper.id]

      Accounts.update_shipper(shipper, %{company: nil, location_id: nil})

      location_users =
        Accounts.get_location!(location.id).shippers
        |> Enum.map(& &1.id)

      assert location_users == []
    end

    test "delete_shipper/1 deletes the shipper" do
      shipper = insert(:shipper)
      assert {:ok, %Shipper{}} = Accounts.delete_shipper(shipper)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_shipper!(shipper.id) end
    end

    test "change_shipper/1 returns a shipper changeset" do
      shipper = insert(:shipper)
      assert %Ecto.Changeset{} = Accounts.change_shipper(shipper)
    end

    test "shipper can have a location" do
      company = company_fixture()
      address = address_fixture()
      location = location_fixture(%{company_id: company.id, address_id: address.id})
      shipper = insert(:shipper, location_id: location.id)

      %{location: %{company: found_company}} = Accounts.get_shipper!(shipper.id)
      assert company.name == found_company.name
    end

    test "add_location_with_shippers updates shipper company field" do
      shipper = insert(:shipper)
      company = insert(:company)

      assert shipper.company != company.name

      location = %{location: "Here"}
      address = %{address: "123 Wherever St", city: "Cincinnati", state: "OH", zip: "45202"}

      Accounts.add_location_with_shippers(%{
        company: company.id,
        location: location,
        address: address,
        shippers: %{users: [shipper]}
      })

      assert Accounts.get_shipper!(shipper.id).company == company.name
    end
  end

  describe "list_account_shippers/2" do
    test "returns empty list when no location" do
      shipper = insert(:shipper, location: nil, role: :member)
      assert Accounts.list_account_shippers(shipper) == {[], 0}
    end

    test "returns all members and location admins for location for member and location admin" do
      company = insert(:company)
      location = insert(:location)

      %{id: member_id} =
        member = insert(:shipper, location: location, role: :member, first_name: "Aaron")

      %{id: location_admin_id} =
        location_admin =
        insert(:shipper, location: location, role: :location_admin, first_name: "Zeke")

      insert(:shipper, location: location, role: :company_admin)

      insert(:shipper, location: insert(:location, company: company))

      assert {[
                %Shipper{id: ^location_admin_id},
                %Shipper{id: ^member_id}
              ], 1} = Accounts.list_account_shippers(member, %{order_by: :first_name})

      assert {[
                %Shipper{id: ^location_admin_id},
                %Shipper{id: ^member_id}
              ], 1} = Accounts.list_account_shippers(location_admin, %{order_by: :first_name})
    end

    test "company admin can see all company shippers" do
      company = insert(:company)
      location = insert(:location, company: company)

      %{id: company_admin_id} =
        company_admin =
        insert(:shipper, location: location, role: :company_admin, first_name: "Zeke")

      %{id: shipper1_id} = insert(:shipper, location: location, first_name: "Aaron")

      %{id: shipper2_id} =
        insert(:shipper, location: insert(:location, company: company), first_name: "Baron")

      insert(:shipper, location: insert(:location))

      assert {[
                %Shipper{id: ^company_admin_id},
                %Shipper{id: ^shipper2_id},
                %Shipper{id: ^shipper1_id}
              ], 1} = Accounts.list_account_shippers(company_admin, %{order_by: :first_name})
    end

    test "company admin can filter by location" do
      company = insert(:company)
      location = insert(:location, company: company)

      %{id: company_admin_id} =
        company_admin =
        insert(:shipper, location: location, role: :company_admin, first_name: "Zeke")

      %{id: shipper_id} = insert(:shipper, location: location, first_name: "Aaron")
      insert(:shipper, location: insert(:location, company: company))

      assert {[
                %Shipper{id: ^company_admin_id},
                %Shipper{id: ^shipper_id}
              ],
              1} =
               Accounts.list_account_shippers(company_admin, %{
                 order_by: :first_name,
                 location_id: location.id
               })
    end

    test "can filter by role" do
      location = insert(:location)

      company_admin = insert(:shipper, location: location, role: :company_admin)

      %{id: shipper_id} = insert(:shipper, location: location, role: :location_admin)
      insert(:shipper, location: location, role: :member)

      assert {[
                %Shipper{id: ^shipper_id}
              ], 1} = Accounts.list_account_shippers(company_admin, %{role: :location_admin})
    end

    test "can filter by disabled" do
      location = insert(:location)

      company_admin = insert(:shipper, location: location, role: :company_admin)

      %{id: shipper_id} = insert(:shipper, location: location, state: "disabled")
      insert(:shipper, location: location, role: :member)

      assert {[
                %Shipper{id: ^shipper_id}
              ], 1} = Accounts.list_account_shippers(company_admin, %{state: "disabled"})
    end
  end

  describe "companies" do
    @valid_attrs %{
      name: "Some company",
      invoice_period: 6,
      account_billing_enabled: true,
      is_enterprise: true,
      auto_cancel: true
    }
    @update_attrs %{
      name: "Some updated company",
      invoice_period: 4,
      account_billing_enabled: true
    }
    @invalid_attrs %{name: nil, account_billing_enabled: false}

    def company_fixture(attrs \\ %{}) do
      {:ok, company} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_company()

      company
    end

    test "list_companies/0 returns all companies" do
      company = company_fixture()
      assert Accounts.list_companies() |> Enum.map(& &1.id) == [company.id]
    end

    test "list_companies_with_schedules/0 returns all companies with schedules" do
      company = company_fixture()
      address = address_fixture()
      location = location_fixture(%{address_id: address.id, company_id: company.id})
      insert(:schedule, location: location)
      company2 = company_fixture()
      location_fixture(%{address_id: address.id, company_id: company2.id})
      assert Accounts.list_companies_with_schedules() |> Enum.map(& &1.id) == [company.id]
    end

    test "get_company!/1 returns the company with given id" do
      company = company_fixture()
      fetched_company = Accounts.get_company!(company.id)
      assert company.name == fetched_company.name
    end

    test "get_company_id_from_shipper/1" do
      %{id: company_id, locations: [%{shippers: [%{id: shipper_id1}]}]} =
        insert(:company_with_location)

      %{id: shipper_id2} = insert(:shipper, location: nil)

      assert Accounts.get_company_id_from_shipper(shipper_id1) == company_id
      assert is_nil(Accounts.get_company_id_from_shipper(shipper_id2))
      assert is_nil(Accounts.get_company_id_from_shipper(nil))
    end

    test "create_company/1 with valid data creates a company" do
      assert {:ok, %Company{} = company} = Accounts.create_company(@valid_attrs)
      assert company.name == "Some company"
      assert company.is_enterprise == true
      assert company.auto_cancel == true
    end

    test "create_company/1 with invalid data returns error changeset" do
      assert {:error, _} = Accounts.create_company(@invalid_attrs)
    end

    test "create_company/1 doesn't require net terms" do
      assert :ok =
               Accounts.create_company(%{
                 company: %{name: "Some Company", account_billing_enabled: false},
                 location: %{location: "1"},
                 address: %{address: "1", city: "2", state: "3", zip: "4"},
                 shippers: %{users: %{}}
               })
    end

    test "create_company/1 does require net terms if account billing is enabled" do
      assert {:error, _} =
               Accounts.create_company(%{
                 company: %{
                   name: "Some Company",
                   account_billing_enabled: true,
                   invoice_period: ""
                 },
                 location: %{location: "1"},
                 address: %{address: "1", city: "2", state: "3", zip: "4"},
                 shippers: %{users: %{}}
               })

      assert :ok =
               Accounts.create_company(%{
                 company: %{
                   name: "Some Company",
                   account_billing_enabled: true,
                   invoice_period: 2
                 },
                 location: %{location: "1"},
                 address: %{address: "1", city: "2", state: "3", zip: "4"},
                 shippers: %{users: %{}}
               })
    end

    test "create_company/1 saves email" do
      assert {:ok, %Company{}} =
               Accounts.create_company(%{name: "Some Company", email: "company@email.com"})
    end

    test "update_company/2 requires net terms only if account billing is enabled" do
      company = company_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_company(company, %{
                 name: company.name,
                 account_billing_enabled: true,
                 invoice_period: ""
               })

      fetched_company = Accounts.get_company!(company.id)
      assert company.invoice_period == fetched_company.invoice_period

      assert {:ok, %Company{} = company} =
               Accounts.update_company(company, %{
                 name: company.name,
                 account_billing_enabled: true,
                 invoice_period: 6
               })

      assert company.invoice_period == 6

      assert {:ok, %Company{} = company} =
               Accounts.update_company(company, %{
                 name: company.name,
                 account_billing_enabled: false,
                 invoice_period: ""
               })

      assert company.invoice_period == nil
    end

    test "update_company/2 with valid data updates the company" do
      company = insert(:company)
      assert {:ok, %Company{} = company} = Accounts.update_company(company, @update_attrs)
      assert company.name == "Some updated company"
    end

    test "update_company/2 doesn't validate locations and shippers" do
      company =
        insert(:company,
          locations: [
            insert(:location,
              address: nil,
              shippers: [build(:shipper, first_name: nil, last_name: nil, phone: nil)]
            )
          ]
        )

      attrs =
        @update_attrs
        |> Map.put(
          :locations,
          Enum.map(
            company.locations,
            fn location ->
              %{
                id: location.id,
                shippers: Enum.map(location.shippers, &Map.from_struct(&1))
              }
            end
          )
        )

      assert {:ok, %Company{} = company} = Accounts.update_company(company, attrs)
      assert company.name == "Some updated company"
    end

    test "update_company/2 with invalid data returns error changeset" do
      company = company_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_company(company, @invalid_attrs)
      fetched_company = Accounts.get_company!(company.id)
      assert company.name == fetched_company.name
    end

    test "delete_company/1 deletes the company" do
      company = company_fixture()
      assert {:ok, %Company{}} = Accounts.delete_company(company)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_company!(company.id) end
    end
  end

  describe "list_companies" do
    test "/0 returns all companies" do
      company = insert(:company)
      assert Accounts.list_companies() |> Enum.map(& &1.id) == [company.id]
    end

    test "returns enterprise customers" do
      insert_list(4, :company, is_enterprise: false)
      insert_list(6, :company, is_enterprise: true)

      assert Accounts.list_companies(%{enterprise_only: true}) |> Enum.count() == 6
    end

    test "/1 returns correct list of companies" do
      [company1, company2, company3] = insert_list(3, :company)
      [location1, location2, _location3] = insert_list(3, :location, company: company1)
      [location4, _location5] = insert_list(2, :location, company: company2)
      [shipper1, shipper2] = insert_list(2, :shipper, location: location1)
      [shipper3, _shipper4] = insert_list(2, :shipper, location: location2)
      shipper5 = insert(:shipper, location: location4)
      insert_list(5, :match, shipper: shipper1, amount_charged: 10_00, state: :completed)
      insert_list(2, :match, shipper: shipper2, amount_charged: 20_00, state: :completed)
      insert_list(3, :match, shipper: shipper3, amount_charged: nil, state: :pending)
      insert_list(7, :match, shipper: shipper5, amount_charged: 500_00, state: :completed)
      refute match?({:error, _}, Accounts.update_company_metrics())

      companies =
        Accounts.list_companies(%{
          page: 0,
          per_page: 10,
          order: :asc,
          order_by: :revenue,
          query: nil
        })
        |> elem(0)

      assert Enum.map(companies, & &1.revenue) == [0, 90_00, 3_500_00]
      assert Enum.map(companies, & &1.id) == [company3.id, company1.id, company2.id]
    end

    test "/1 returns proper company metrics" do
      company = insert(:company, name: "Company Name")
      locations = insert_list(5, :location, company: company)

      locations_with_shippers =
        Enum.map(locations, &insert_list(3, :shipper, state: "approved", location: &1))

      Enum.each(
        locations_with_shippers,
        &Enum.each(&1, fn s ->
          insert_list(4, :match, state: :charged, amount_charged: 10_00, shipper: s)
        end)
      )

      # 1 company, 5 locations, 15 shippers, 60 matches, 600_00 in revenue
      refute match?({:error, _}, Accounts.update_company_metrics())

      assert %Company{location_count: 5, shipper_count: 15, match_count: 60, revenue: 600_00} =
               Accounts.list_companies(%{
                 page: 0,
                 per_page: 10,
                 order: :asc,
                 order_by: :name,
                 query: nil
               })
               |> elem(0)
               |> List.first()

      assert %Company{location_count: 5, shipper_count: 15, match_count: 60, revenue: 600_00} =
               Accounts.list_companies(%{
                 page: 0,
                 per_page: 10,
                 order: :asc,
                 order_by: :name,
                 query: "Company Name"
               })
               |> elem(0)
               |> List.first()

      assert %Company{location_count: 5, shipper_count: 15, match_count: 60, revenue: 600_00} =
               Accounts.list_companies(%{
                 page: 0,
                 per_page: 10,
                 order: :asc,
                 order_by: :revenue,
                 query: "Company Name"
               })
               |> elem(0)
               |> List.first()

      assert %Company{location_count: 5, shipper_count: 15, match_count: 60, revenue: 600_00} =
               Accounts.list_companies(%{
                 page: 0,
                 per_page: 10,
                 order: :asc,
                 order_by: :shipper_count,
                 query: nil
               })
               |> elem(0)
               |> List.first()
    end
  end

  describe "schedules" do
    test "create schedule" do
      %{id: location_id} = insert(:location)
      time = %Time{hour: 10, minute: 30, second: 0}

      attrs = %{
        location_id: location_id,
        monday: time,
        wednesday: time,
        friday: time,
        max_drivers: 7,
        min_drivers: 3,
        sla: 3
      }

      assert {:ok,
              %Schedule{
                location_id: ^location_id,
                monday: ^time,
                tuesday: nil,
                wednesday: ^time,
                thursday: nil,
                friday: ^time,
                saturday: nil,
                sunday: nil,
                min_drivers: 3,
                max_drivers: 7,
                sla: 3
              }} = Accounts.create_schedule(attrs)
    end

    test "get schedule" do
      %{id: schedule_id} = insert(:schedule)

      assert %Schedule{id: ^schedule_id} = Accounts.get_schedule(schedule_id)
    end

    test "list all unaccepted schedules for driver" do
      %{driver: driver} = insert(:driver_location, geo_location: chris_house_point())
      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, chris_house_point())

      insert_list(5, :schedule)
      |> Enum.map(&DriverNotification.send_fleet_opportunity_notifications(&1, 90, true))

      schedules = Accounts.list_unaccepted_schedules_for_driver(driver)
      assert schedules |> Enum.count() == 5
    end

    test "does not list schedules driver already accepted" do
      %{driver: %{id: driver_id} = driver} =
        insert(:driver_location, geo_location: chris_house_point())

      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, chris_house_point())

      [%{id: schedule_id} | _] = schedules = insert_list(5, :schedule)
      Accounts.add_driver_to_schedule(%{schedule_id: schedule_id, driver_id: driver_id})

      schedules
      |> Enum.map(&DriverNotification.send_fleet_opportunity_notifications(&1, 90, true))

      schedules = Accounts.list_unaccepted_schedules_for_driver(driver)
      assert schedules |> Enum.count() == 4
    end

    test "update schedule" do
      time2 = %Time{hour: 3, minute: 14, second: 0}

      schedule = insert(:schedule)

      assert {:ok, %{monday: ^time2, sunday: ^time2, sla: 6}} =
               Accounts.update_schedule(schedule, %{monday: time2, sunday: time2, sla: 6})
    end

    test "add driver to schedule" do
      %{id: schedule_id} = insert(:schedule)
      %{id: driver_id} = insert(:driver)

      assert {:ok, %{schedule_id: ^schedule_id, driver_id: ^driver_id}} =
               Accounts.add_driver_to_schedule(%{schedule_id: schedule_id, driver_id: driver_id})

      assert %Schedule{id: ^schedule_id, drivers: [%{id: ^driver_id}]} =
               Accounts.get_schedule(schedule_id) |> FraytElixir.Repo.preload(:drivers)
    end

    test "remove driver from schedule" do
      %{id: schedule_id, drivers: [%{id: driver1_id}, %{id: driver2_id}]} =
        insert(:schedule_with_drivers)

      Accounts.remove_driver_from_schedule(schedule_id, driver1_id)

      assert %Schedule{id: ^schedule_id, drivers: [%{id: ^driver2_id}]} =
               Accounts.get_schedule(schedule_id) |> FraytElixir.Repo.preload(:drivers)
    end

    test "doesn't create or update a schedule with invalid fields" do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Accounts.create_schedule(%{max_drivers: 3, min_drivers: nil})

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Accounts.update_schedule(insert(:schedule), %{min_drivers: 7, max_drivers: 2})
    end
  end

  describe "locations" do
    alias FraytElixir.Accounts.Location

    @valid_attrs %{
      location: "Some location",
      store_number: "Some store number",
      email: "some@email.com"
    }
    @update_attrs %{location: "Some updated location"}
    @invalid_attrs %{location: nil}

    def location_fixture(attrs \\ %{}) do
      {:ok, location} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_location()

      location |> Repo.preload(:address)
    end

    def address_fixture(attrs \\ %{}) do
      {:ok, address} =
        attrs
        |> Enum.into(%{
          address: "708 Walnut St.",
          address2: "",
          city: "Cincinnati",
          state: "OH",
          zip: "45202"
        })
        |> Shipment.create_address()

      address
    end

    def address_map(address) do
      %{
        id: address.id,
        address: address.address,
        address2: address.address2,
        city: address.city,
        state: address.state,
        zip: address.zip
      }
    end

    test "list_locations/1 returns all locations" do
      %{id: location_id} = insert(:location)

      assert {[%Location{id: ^location_id}], 1} =
               Accounts.list_locations(%{query: nil, parent_id: nil})
    end

    test "list_locations/1 filters by company" do
      company = insert(:company)
      %{id: location_id} = insert(:location, company: company)
      insert(:location)

      assert {[%Location{id: ^location_id}], 1} =
               Accounts.list_locations(%{query: nil, parent_id: company.id})
    end

    test "list_locations/1 filters by query" do
      company = insert(:company)
      %{id: location_id} = insert(:location, company: company, location: "Home")
      insert(:location, company: company, location: "Away")
      insert(:location, location: "Home")

      assert {[%Location{id: ^location_id}], 1} =
               Accounts.list_locations(%{query: "Hom", parent_id: company.id})
    end

    test "list_company_locations_with_schedules/1 returns all locations for a given company" do
      company = company_fixture()
      company2 = company_fixture()
      address = address_fixture()

      location =
        location_fixture(%{
          company_id: company.id,
          address_id: address.id
        })

      insert(:schedule, location: location)

      location_fixture(%{company_id: company.id, address_id: address.id})
      location_fixture(%{company_id: company2.id, address_id: address.id})

      assert Accounts.list_company_locations_with_schedules(company.id) |> Enum.map(& &1.id) == [
               location.id
             ]
    end

    test "get_location!/1 returns the location with given id" do
      company = company_fixture()
      address = address_fixture()
      location = location_fixture(%{company_id: company.id, address_id: address.id})
      fetched_location = Accounts.get_location!(location.id)
      assert location.location == fetched_location.location
    end

    test "get_location_revenue/1" do
      location = insert(:location)
      location2 = insert(:location)
      shippers = insert_list(3, :shipper_with_location, location: location)

      Enum.each(
        shippers,
        &insert_list(2, :match, amount_charged: 10_00, shipper: &1, state: :completed)
      )

      assert Accounts.get_location_revenue(location2.id) == 0
      assert Accounts.get_location_revenue(location.id) == 60_00
    end

    test "create_location/1 with valid data creates a location" do
      company = company_fixture()
      address = address_fixture()
      attrs = @valid_attrs |> Map.put(:company_id, company.id) |> Map.put(:address_id, address.id)
      assert {:ok, %Location{} = location} = Accounts.create_location(attrs)
      assert location.location == "Some location"
    end

    test "create_location/1 saved net terms/invoice_period" do
      company = company_fixture()
      address = address_fixture()

      assert {:ok, %Location{} = location} =
               Accounts.create_location(%{
                 company_id: company.id,
                 address_id: address.id,
                 invoice_period: 12,
                 location: "Location Name"
               })

      assert location.location == "Location Name"
      assert location.invoice_period == 12
    end

    test "create_location/1 fails if the company does not exist" do
      bad_company_id = Ecto.UUID.generate()
      address = address_fixture()

      attrs =
        @valid_attrs |> Map.put(:company_id, bad_company_id) |> Map.put(:address_id, address.id)

      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_location(attrs)
      assert {"does not exist", _} = changeset.errors[:company_id]
    end

    test "create_location/1 fails if the company_id is nil" do
      bad_company_id = nil
      attrs = @valid_attrs |> Map.put(:company_id, bad_company_id)
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_location(attrs)
      assert {"can't be blank", _} = changeset.errors[:company_id]
    end

    test "create_location/1 with invalid data returns error changeset" do
      assert {:error, _} = Accounts.create_location(@invalid_attrs)
    end

    test "update_location/2 with valid data updates the location" do
      company = company_fixture()
      address = address_fixture()

      location =
        location_fixture(%{company_id: company.id, address_id: address.id, address: address})

      assert {:ok, %Location{} = location} =
               Accounts.update_location(
                 location,
                 @update_attrs |> Map.put(:address, address_map(address))
               )

      assert location.location == "Some updated location"
    end

    test "update_location/2 with invalid data returns error changeset" do
      company = company_fixture()
      address = address_fixture()

      location =
        location_fixture(%{company_id: company.id, address_id: address.id, address: address})

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_location(
                 location,
                 @invalid_attrs |> Map.put(:address, address_map(address))
               )

      fetched_location = Accounts.get_location!(location.id)
      assert location.location == fetched_location.location
    end

    test "update_location/2 updates and receives errors from address" do
      company = company_fixture()
      address = address_fixture()

      location =
        location_fixture(%{company_id: company.id, address_id: address.id, address: address})

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_location(location, %{address: %{id: address.id, address: ""}})

      fetched_location = Accounts.get_location!(location.id) |> Repo.preload(:address)
      assert location.address == fetched_location.address

      assert {:ok, %Location{} = location} =
               Accounts.update_location(location, %{
                 address: %{
                   id: address.id,
                   address: "4533 Ruebel Place",
                   city: "Cincinnati",
                   state: "Ohio",
                   zip: "45211"
                 }
               })

      assert location.address.address == "4533 Ruebel Place"
    end

    test "delete_location/1 deletes the location" do
      company = company_fixture()
      address = address_fixture()
      location = location_fixture(%{company_id: company.id, address_id: address.id})
      assert {:ok, %Location{}} = Accounts.delete_location(location)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_location!(location.id) end
    end
  end

  describe "update_account_shipper" do
    test "updates shipper" do
      location = insert(:location)
      admin = insert(:shipper, role: :location_admin, location: location)
      shipper = insert(:shipper, first_name: "Joe", location: location)

      assert {:ok, %Shipper{first_name: "Bob"}} =
               Accounts.update_account_shipper(admin, shipper, %{first_name: "Bob"})
    end

    test "returns error when company admin updates role to company_admin" do
      location = insert(:location)
      admin = insert(:shipper, role: :company_admin, location: location)
      shipper = insert(:shipper, role: :location_admin, first_name: "joe", location: location)

      assert {:error,
              %Changeset{
                errors: [
                  role: {"is invalid", [validation: :inclusion, enum: [:location_admin, :member]]}
                ]
              }} = Accounts.update_account_shipper(admin, shipper, %{role: :company_admin})
    end

    test "returns error when company admin updates to external location" do
      company = insert(:company)
      %{id: location_id} = location = insert(:location, company: company)
      %{id: other_location_id} = other_location = insert(:location, company: company)
      external_location = insert(:location)

      admin =
        insert(:shipper, role: :company_admin, location: location)
        |> Repo.preload(location: [company: :locations])

      shipper = insert(:shipper, role: :location_admin, location: other_location)

      assert {:error,
              %Changeset{
                errors: [
                  location_id:
                    {"is invalid",
                     [
                       validation: :inclusion,
                       enum: [^location_id, ^other_location_id]
                     ]}
                ]
              }} =
               Accounts.update_account_shipper(admin, shipper, %{
                 location_id: external_location.id
               })
    end

    test "returns error when location admin updates to other location or role" do
      company = insert(:company)
      %{id: location_id} = location = insert(:location, company: company)
      other_location = insert(:location, company: company)

      admin =
        insert(:shipper, role: :location_admin, location: location)
        |> Repo.preload(location: [company: :locations])

      member = insert(:shipper, role: :member, location: location)

      assert {:error,
              %Changeset{
                errors: [role: {"is invalid", [validation: :inclusion, enum: [:member]]}]
              }} = Accounts.update_account_shipper(admin, member, %{role: :location_admin})

      assert {:error,
              %Changeset{
                errors: [
                  location_id:
                    {"is invalid",
                     [
                       validation: :inclusion,
                       enum: [^location_id]
                     ]}
                ]
              }} =
               Accounts.update_account_shipper(admin, member, %{location_id: other_location.id})
    end

    test "returns error when member tries to update shipper " do
      location = insert(:location)
      shipper = insert(:shipper, role: :member, location: location)
      member = insert(:shipper, role: :member, location: location)

      assert {:error,
              %Changeset{
                errors: [role: {"cannot be edited by a member", [validation: :account_shipper]}]
              }} = Accounts.update_account_shipper(member, shipper, %{first_name: "Joe"})
    end
  end

  describe "create_account_shipper" do
    test "creates a shipper" do
      %{id: sales_rep_id} = sales_rep = insert(:admin_user)
      %{id: location_id} = location = insert(:location, sales_rep: sales_rep)
      admin = insert(:shipper, role: :location_admin, location: location)

      assert {:ok,
              %Shipper{
                first_name: "Bob",
                last_name: "Jones",
                role: :member,
                user: %{email: "joe@example.com"},
                location_id: ^location_id,
                sales_rep_id: ^sales_rep_id
              }} =
               Accounts.create_account_shipper(admin, %{
                 first_name: "Bob",
                 last_name: "Jones",
                 role: :member,
                 user: %{email: "joe@example.com"},
                 phone: "0000000",
                 location_id: location.id
               })
    end

    test "fails to create a shipper without location" do
      location = insert(:location)
      admin = insert(:shipper, role: :location_admin, location: location)

      assert {:error, %Changeset{errors: [location_id: {_, [validation: :required]}]}} =
               Accounts.create_account_shipper(admin, %{
                 first_name: "Bob",
                 last_name: "Jones",
                 role: :member,
                 user: %{email: "joe@example.com"},
                 phone: "0000000"
               })
    end
  end

  describe "change password" do
    test "updates password" do
      user = insert(:user, password: "secretpassword")

      params = %{
        "old" => "secretpassword",
        "new" => "newpassword@1"
      }

      assert {:ok, %User{}} = Accounts.change_password(user, params)
    end

    test "fails if you start with the wrong password" do
      user = insert(:user, password: "secretpassword")

      params = %{
        "old" => "wrongpassword",
        "new" => "newpassword@1"
      }

      assert {:error, :invalid_credentials} = Accounts.change_password(user, params)
    end
  end

  describe "set_password_reset_code" do
    test "succeeds with valid user" do
      user = insert(:user, password_reset_code: nil)

      assert {:ok, %User{password_reset_code: password_reset_code}} =
               Accounts.set_password_reset_code(user)

      assert String.length(password_reset_code) == 8
    end

    test "succeeds with valid user and code" do
      user = insert(:user, password_reset_code: nil)
      code = "123RTYI"

      assert {:ok, %User{password_reset_code: ^code}} =
               Accounts.set_password_reset_code(user, code)
    end

    test "fails with invalid user" do
      assert {:error, :invalid_user} = Accounts.set_password_reset_code(nil)
    end

    test "fails with valid user and invalid code" do
      user = insert(:user)
      assert {:error, :invalid_user} = Accounts.set_password_reset_code(user, 12)
    end
  end

  describe "forgot password" do
    test "regular user" do
      %{user: %User{email: email, id: user_id}} = insert(:shipper)

      Accounts.forgot_password(email)

      assert %User{password_reset_code: code} = Repo.get(User, user_id)
      assert String.length(code) > 0
      assert {:ok, _} = Accounts.authenticate(email, code, :shipper)
    end

    test "user migrated from bubble" do
      %{user: %User{email: email, id: user_id}} =
        insert(:shipper, user: build(:user, auth_via_bubble: true))

      Accounts.forgot_password(email)

      assert %User{password_reset_code: code} = Repo.get(User, user_id)
      assert String.length(code) > 0
      assert {:error, _} = Accounts.authenticate(email, "not_the_code", :shipper)
      assert {:ok, _} = Accounts.authenticate(email, code, :shipper)
    end
  end

  describe "admin users" do
    test "list_sales_reps" do
      insert_list(3, :admin_user, role: "admin")
      insert_list(4, :admin_user, role: "sales_rep")
      insert_list(2, :admin_user, role: "sales_rep", disabled: true)

      assert Enum.count(Accounts.list_sales_reps()) == 4
    end

    test "invite admin user" do
      {:ok, admin} =
        Accounts.invite_admin(%{user: %{email: "test@email.com"}, role: "admin", name: "Test"})

      assert admin.user.email == "test@email.com"
      assert admin.role == :admin
    end

    test "update admin user" do
      admin =
        insert(:admin_user,
          name: "Some Name",
          role: "network_operator",
          user: build(:user, email: "some.test@email.com", password_reset_code: "ABC123")
        )

      assert admin.name == "Some Name"
      assert admin.role == :network_operator
      assert admin.user.email == "some.test@email.com"
      assert admin.user.password_reset_code == "ABC123"

      {:ok, updated_user} =
        Accounts.update_admin_password(admin.user, %{
          password: "dk21!sdf",
          password_confirmation: "dk21!sdf",
          password_reset_code: nil
        })

      assert is_nil(updated_user.password_reset_code)

      {:ok, updated_admin} =
        Map.put(admin, :user, updated_user)
        |> Accounts.update_admin(%{
          name: "Another Name",
          role: "admin",
          user: %{id: admin.user.id, email: "another@email.com"}
        })

      assert updated_admin.name == "Another Name"
      assert updated_admin.role == :admin
      assert updated_admin.user.email == "another@email.com"
      assert updated_admin.user.password == "dk21!sdf"
    end

    test "invite_admins/1 with valid emails" do
      admins_attrs = %{user: %{email: "alex@gaslight.co"}, role: "admin", name: "Alex"}

      assert {
               :ok,
               %AdminUser{
                 role: :admin,
                 user: %User{
                   email: "alex@gaslight.co",
                   password_reset_code: password_reset_code
                 }
               }
             } = Accounts.invite_admin(admins_attrs)

      expected_email =
        Email.invitation_email(%{
          email: "alex@gaslight.co",
          password_reset_code: password_reset_code,
          name: "Alex"
        })

      assert(password_reset_code)
      assert_delivered_email(expected_email)
    end

    test "invite_admins/1 with invalid emails" do
      admins_attrs = %{user: %{email: "alex@gaslight.co"}, role: "admin", name: "Alex"}

      assert {:ok,
              %AdminUser{
                role: :admin,
                user: %User{
                  email: "alex@gaslight.co",
                  password_reset_code: password_reset_code
                }
              }} = Accounts.invite_admin(admins_attrs)

      expected_email =
        Email.invitation_email(%{
          email: "alex@gaslight.co",
          password_reset_code: password_reset_code,
          name: "Alex"
        })

      assert_delivered_email(expected_email)
    end

    test "admin cannot reset password if their account is disabled" do
      admin = insert(:admin_user, disabled: true, user: build(:user))

      assert Accounts.reset_admin_password(%{email: admin.user.email}) == :disabled
    end

    test "disable admin user account" do
      %AdminUser{user: %User{email: email}} =
        insert(:admin_user, disabled: false, user: build(:user))

      assert {:ok, %AdminUser{disabled: true}} = Accounts.disable_admin_account(email)
      assert {:error, :not_found} = Accounts.disable_admin_account("garbage")
    end

    test "enable admin user account" do
      %AdminUser{user: %User{email: email}} =
        insert(:admin_user, disabled: false, user: build(:user))

      %AdminUser{user: %User{email: email2}} =
        insert(:admin_user, disabled: true, user: build(:user))

      assert {:ok, :enabled} = Accounts.enable_admin_account(email2)
      assert {:error, :not_disabled} = Accounts.enable_admin_account(email)
      assert {:error, :not_found} = Accounts.enable_admin_account("garbage")
    end

    test "delete admin user" do
      admin =
        insert(:admin_user,
          name: "Some Name",
          role: "network_operator",
          user: build(:user, password: "sd@kl1kj", email: "some.test@email.com")
        )

      assert Enum.count(Accounts.list_users()) == 1
      assert Enum.count(Accounts.list_admins()) == 1

      Accounts.remove_admin(admin)
      assert Accounts.list_users() == []
      assert Accounts.list_admins() == []
    end

    test "admin user has sales goal" do
      {:ok, admin} =
        Accounts.invite_admin(%{
          name: "Test",
          user: %{email: "test@email.com"},
          role: "sales_rep",
          sales_goal: 200_00
        })

      assert admin.sales_goal == 200_00

      {:ok, updated_admin} = Accounts.update_admin(admin, %{sales_goal: 300_00})
      assert updated_admin.sales_goal == 300_00
    end

    test "get_admin_by_email/1 returns admin" do
      %{id: admin_id, user: %{email: email}} = insert(:admin_user)
      assert %AdminUser{id: ^admin_id} = Accounts.get_admin_by_email(email)
    end

    test "get_admin_by_email/1 returns nil with bad email" do
      assert nil == Accounts.get_admin_by_email("adfasdf")
    end

    test "get_admin_by_email/1 returns nil when nil is passed" do
      assert nil == Accounts.get_admin_by_email(nil)
    end
  end

  describe "company_has_account_billing?" do
    test "with nil id" do
      assert Accounts.company_has_account_billing?(nil) == nil
    end

    test "when account_billing_enabled is true" do
      company = insert(:company, account_billing_enabled: true)

      assert Accounts.company_has_account_billing?(company.id) == true
    end

    test "when account_billing_enabled is false" do
      company = insert(:company, account_billing_enabled: false)

      assert Accounts.company_has_account_billing?(company.id) == false
    end
  end

  describe "get_company_invoice_period" do
    test "with nil id" do
      assert Accounts.get_company_invoice_period(nil) == nil
    end

    test "when invoice period exists" do
      company = insert(:company, invoice_period: 12)

      assert Accounts.get_company_invoice_period(company.id) == 12
    end

    test "when invoice period is nil" do
      company = insert(:company, invoice_period: nil)

      assert Accounts.get_company_invoice_period(company.id) == nil
    end
  end

  describe "get company sales rep id" do
    test "when company has a sales rep" do
      admin = insert(:admin_user, role: "sales_rep")
      company = insert(:company, sales_rep: admin)

      assert Accounts.get_company_sales_rep_id(company.id) == admin.id
    end

    test "when company has no sales rep" do
      company = insert(:company)

      assert Accounts.get_company_sales_rep_id(company.id) == nil
    end

    test "when company id is nil" do
      assert Accounts.get_company_sales_rep_id(nil) == nil
    end
  end

  describe "get_shipper_email" do
    test "returns user email" do
      shipper = insert(:shipper)
      assert shipper.user.email == Accounts.get_shipper_email(shipper)
    end

    test "returns user email for shipper without preloaded user" do
      shipper = insert(:shipper)
      fetched_shipper = Repo.get!(Shipper, shipper.id)
      assert shipper.user.email == Accounts.get_shipper_email(fetched_shipper)
    end

    test "returns nil when empty shipper is passed" do
      refute Accounts.get_shipper_email(%Shipper{})
    end

    test "returns nil when nil is passed" do
      refute Accounts.get_shipper_email(nil)
    end
  end

  describe "get_match_company" do
    test "returns match company" do
      %{shipper: %{location: %{company: %{id: company_id}}}} =
        match = insert(:match, shipper: build(:shipper_with_location_auto_cancel))

      assert %Company{id: ^company_id} = Accounts.get_match_company(match)
    end

    test "returns match company when shipper not preloaded" do
      %{id: match_id, shipper: %{location: %{company: %{id: company_id}}}} =
        insert(:match, shipper: build(:shipper_with_location_auto_cancel))

      match = Repo.get!(Match, match_id)

      assert %Company{id: ^company_id} = Accounts.get_match_company(match)
    end

    test "returns match company when location not preloaded" do
      %{id: match_id, shipper: %{location: %{company: %{id: company_id}}}} =
        insert(:match, shipper: build(:shipper_with_location_auto_cancel))

      match = Repo.get!(Match, match_id) |> Repo.preload(:shipper)

      assert %Company{id: ^company_id} = Accounts.get_match_company(match)
    end

    test "returns match company when company not preloaded" do
      %{id: match_id, shipper: %{location: %{company: %{id: company_id}}}} =
        insert(:match, shipper: build(:shipper_with_location_auto_cancel))

      match = Repo.get!(Match, match_id) |> Repo.preload(shipper: :location)

      assert %Company{id: ^company_id} = Accounts.get_match_company(match)
    end

    test "returns nil when no shipper" do
      match = insert(:match, shipper: nil)
      assert nil == Accounts.get_match_company(match)
    end

    test "returns nil when no company" do
      match = insert(:match, shipper: build(:shipper))
      assert nil == Accounts.get_match_company(match)
    end
  end

  describe "toggle_admin_theme" do
    test "toggles" do
      admin = insert(:admin_user, site_theme: nil)

      assert {:ok, %AdminUser{site_theme: :dark} = admin} = Accounts.toggle_admin_theme(admin)
      assert {:ok, %AdminUser{site_theme: :light} = admin} = Accounts.toggle_admin_theme(admin)
      assert {:ok, %AdminUser{site_theme: :dark}} = Accounts.toggle_admin_theme(admin)
    end
  end

  describe "list_admins" do
    test "lists admins by name" do
      %{id: admin1_id} = insert(:admin_user, name: "John Smith")

      %{id: admin2_id} =
        insert(:admin_user,
          name: "Joe Williams",
          user: build(:user, email: "joe@smithenterprises.com")
        )

      insert(:admin_user, name: "Bobby", user: build(:user, email: "bob@example.com"))

      assert {[%AdminUser{id: ^admin1_id}, %AdminUser{id: ^admin2_id}], 1} =
               Accounts.list_admins(%{query: "smith", order_by: :name, order: :desc})
    end

    test "lists admins by phone number" do
      insert(:admin_user, name: "Bobby", user: build(:user, email: "bobby@example.com"))
      insert(:admin_user, name: "Bob", user: build(:user, email: "bob@example.com"))

      %{id: admin1_id} = insert(:admin_user, name: "John Smith", phone_number: "+12016394134")

      assert {[%AdminUser{id: ^admin1_id}], 1} =
               Accounts.list_admins(%{query: "4134", order_by: :name, order: :desc})
    end

    test "lists all admins when no query" do
      insert_list(10, :admin_user)

      assert {results, 1} = Accounts.list_admins(%{})

      assert results |> Enum.count() == 10
    end
  end

  describe "list_agreement_documents" do
    test "lists agreements" do
      %{id: doc1_id} = insert(:agreement_document, type: :eula, title: "nonsense")
      %{id: doc2_id} = insert(:agreement_document, type: :delivery_agreement, title: "eula")
      insert(:agreement_document, type: :responsibility_agreement, title: "responsibility")

      assert {[%AgreementDocument{id: ^doc1_id}, %AgreementDocument{id: ^doc2_id}], 1} =
               Accounts.list_agreement_documents(%{query: "eula", order_by: :title, order: :desc})
    end

    test "lists all agreements when no query" do
      insert(:agreement_document, type: :eula)
      insert(:agreement_document, type: :delivery_agreement)
      insert(:agreement_document, type: :responsibility_agreement)

      assert {results, 1} = Accounts.list_agreement_documents(%{})

      assert results |> Enum.count() == 3
    end
  end

  describe "list_pending_agreements" do
    test "lists agreements" do
      shipper = insert(:shipper)

      %{id: doc_id, support_documents: [%{id: support_doc_id}]} =
        insert(:agreement_document,
          type: :eula,
          user_types: [:shipper],
          support_documents: [insert(:agreement_document, type: :responsibility_agreement)]
        )

      insert(:agreement_document,
        user_types: [:driver],
        type: :responsibility_agreement,
        title: "responsibility"
      )

      assert [
               %AgreementDocument{
                 id: ^doc_id,
                 support_documents: [%AgreementDocument{id: ^support_doc_id}]
               }
             ] = Accounts.list_pending_agreements(shipper)
    end

    test "filters from user types including support docs" do
      shipper = insert(:shipper)

      %{id: doc_id, support_documents: [%{id: sup_doc_id} | _]} =
        insert(:agreement_document,
          type: :eula,
          user_types: [:shipper, :driver],
          support_documents: [
            insert(:agreement_document,
              type: :delivery_agreement,
              user_types: [:shipper]
            ),
            insert(:agreement_document,
              type: :responsibility_agreement,
              user_types: [:driver]
            )
          ]
        )

      insert(:agreement_document,
        state: :draft,
        user_types: [:driver],
        type: :delivery_agreement,
        title: "responsibility"
      )

      assert [%AgreementDocument{id: ^doc_id, support_documents: [%{id: ^sup_doc_id}]}] =
               Accounts.list_pending_agreements(shipper)
    end

    test "ignores drafts" do
      shipper = insert(:shipper)

      %{id: doc_id} =
        insert(:agreement_document,
          type: :eula,
          user_types: [:shipper],
          support_documents: [
            insert(:agreement_document, type: :responsibility_agreement, state: :draft)
          ]
        )

      insert(:agreement_document,
        state: :draft,
        user_types: [:shipper],
        type: :delivery_agreement,
        title: "responsibility"
      )

      assert [%AgreementDocument{id: ^doc_id, support_documents: []}] =
               Accounts.list_pending_agreements(shipper)
    end

    test "handles no user" do
      shipper = insert(:shipper)

      %{id: doc_id} =
        insert(:agreement_document,
          type: :eula,
          user_types: [:shipper],
          updated_at: ~N[2021-01-01 00:00:00],
          agreements: [
            build(:user_agreement,
              user: shipper.user,
              updated_at: ~N[2020-01-01 00:00:00],
              document: nil
            )
          ]
        )

      assert [%AgreementDocument{id: ^doc_id}] = Accounts.list_pending_agreements(:shipper)
    end

    test "returns updated agreements for already agreed docs" do
      shipper = insert(:shipper)

      %{id: doc1_id} =
        insert(:agreement_document,
          user_types: [:shipper],
          type: :eula,
          updated_at: ~N[2021-01-01 00:00:00],
          agreements: [
            build(:user_agreement,
              user: shipper.user,
              updated_at: ~N[2020-01-01 00:00:00],
              document: nil
            )
          ]
        )

      %{id: doc2_id} =
        insert(:agreement_document,
          user_types: [:shipper],
          type: :delivery_agreement,
          updated_at: ~N[2020-01-01 00:00:00],
          agreements: [
            build(:user_agreement,
              updated_at: ~N[2021-01-01 00:00:00],
              document: nil
            )
          ]
        )

      # updated support docs mean that parent doc needs reagreed to.
      %{id: doc3_id} =
        insert(:agreement_document,
          user_types: [:shipper],
          type: :delivery_agreement,
          updated_at: ~N[2020-01-01 00:00:00],
          support_documents: [
            insert(:agreement_document,
              user_types: [:shipper],
              type: :delivery_agreement,
              updated_at: ~N[2021-01-01 00:00:00],
              agreements: [
                build(:user_agreement,
                  updated_at: ~N[2020-01-01 00:00:00],
                  document: nil,
                  user: shipper.user
                )
              ]
            ),
            insert(:agreement_document,
              user_types: [:shipper],
              type: :delivery_agreement,
              updated_at: ~N[2021-01-01 00:00:00],
              agreements: [
                build(:user_agreement,
                  updated_at: ~N[2020-01-01 00:00:00],
                  document: nil,
                  user: shipper.user
                )
              ]
            )
          ],
          agreements: [
            build(:user_agreement,
              updated_at: ~N[2021-01-01 00:00:00],
              document: nil,
              user: shipper.user
            )
          ]
        )

      insert(:agreement_document,
        user_types: [:shipper],
        type: :responsibility_agreement,
        updated_at: ~N[2020-01-01 00:00:00],
        agreements: [
          build(:user_agreement,
            user: shipper.user,
            updated_at: ~N[2021-01-01 00:00:00],
            document: nil
          )
        ]
      )

      assert [
               %AgreementDocument{id: ^doc1_id},
               %AgreementDocument{id: ^doc2_id},
               %AgreementDocument{id: ^doc3_id}
             ] =
               Accounts.list_pending_agreements(shipper)
               |> sort_by_list([doc1_id, doc2_id, doc3_id], & &1.id)
    end

    test "returns empty list for already agreed agreements" do
      shipper = insert(:shipper)

      insert(:agreement_document,
        user_types: [:shipper],
        type: :delivery_agreement,
        updated_at: ~N[2020-01-01 00:00:00],
        agreements: [
          build(:user_agreement,
            updated_at: ~N[2021-01-01 00:00:00],
            document: nil,
            user: shipper.user
          ),
          build(:user_agreement,
            updated_at: ~N[2020-01-01 00:00:00],
            document: nil
          ),
          build(:user_agreement,
            updated_at: ~N[2021-01-01 00:00:00],
            document: nil
          )
        ]
      )

      assert [] == Accounts.list_pending_agreements(shipper)
    end
  end

  describe "get_agreement_document" do
    test "gets agreement document" do
      %{id: doc_id} = insert(:agreement_document)
      assert {:ok, %AgreementDocument{id: ^doc_id}} = Accounts.get_agreement_document(doc_id)
    end

    test "returns not found for nil" do
      insert(:agreement_document)
      assert {:error, :not_found} = Accounts.get_agreement_document(nil)
    end

    test "returns not found for invalid id" do
      insert(:agreement_document)
      assert {:error, :not_found} = Accounts.get_agreement_document("ajsfhdasdfjasfhl")
    end

    test "returns not found for non existent id" do
      insert(:agreement_document)
      %{id: shipper_id} = insert(:shipper)
      assert {:error, :not_found} = Accounts.get_agreement_document(shipper_id)
    end
  end

  describe "delete_agreement_document" do
    test "deletes document and user agreements" do
      document =
        %{
          id: doc_id,
          support_documents: [%{id: sup_doc_id} | _],
          agreements: [%{id: agreement_id}]
        } =
        insert(:agreement_document,
          type: :eula,
          user_types: [:shipper, :driver],
          support_documents: [
            insert(:agreement_document,
              type: :delivery_agreement,
              user_types: [:shipper]
            )
          ],
          agreements: [
            build(:user_agreement, document: nil)
          ]
        )

      assert {:ok, %AgreementDocument{id: ^doc_id}} = Accounts.delete_agreement_document(document)

      refute Repo.get(AgreementDocument, doc_id)
      refute Repo.get(UserAgreement, agreement_id)
      assert %AgreementDocument{parent_document_id: nil} = Repo.get(AgreementDocument, sup_doc_id)
    end
  end

  describe "accept_agreements" do
    test "accepts agreements" do
      %{user_id: user_id} = shipper = insert(:shipper)

      %{id: document_id, support_documents: [%{id: support_document_id}]} =
        insert(:agreement_document, support_documents: [build(:agreement_document)])

      assert {:ok, agreements} =
               Accounts.accept_agreements(shipper, [
                 %{document_id: document_id, agreed: true, updated_at: ~N[2020-01-01 00:00:00]}
               ])

      assert [
               %UserAgreement{
                 document_id: ^document_id,
                 user_id: ^user_id,
                 updated_at: ~N[2020-01-01 00:00:00],
                 agreed: true
               },
               %UserAgreement{
                 document_id: ^support_document_id,
                 user_id: ^user_id,
                 updated_at: ~N[2020-01-01 00:00:00],
                 agreed: true
               }
             ] = agreements |> sort_by_list([document_id, support_document_id], & &1.document_id)
    end

    test "accepts existing agreements" do
      %{user_id: user_id} = shipper = insert(:shipper)

      %{id: document_id, support_documents: [%{id: support_document_id}]} =
        document =
        insert(:agreement_document,
          support_documents: [build(:agreement_document, type: :delivery_agreement)]
        )

      %{id: agreement_id} =
        insert(:user_agreement,
          document: document,
          user: shipper.user,
          updated_at: ~N[2020-01-01 00:00:00]
        )

      assert {:ok, agreements} =
               Accounts.accept_agreements(shipper, [
                 %{document_id: document_id, agreed: true, updated_at: ~N[2021-01-01 00:00:00]}
               ])

      assert [
               %UserAgreement{
                 id: ^agreement_id,
                 document_id: ^document_id,
                 user_id: ^user_id,
                 updated_at: ~N[2021-01-01 00:00:00],
                 agreed: true
               },
               %UserAgreement{
                 id: _,
                 document_id: ^support_document_id,
                 user_id: ^user_id,
                 updated_at: ~N[2021-01-01 00:00:00],
                 agreed: true
               }
             ] = agreements |> sort_by_list([document_id, support_document_id], & &1.document_id)
    end

    test "returns error for rejected docs" do
      shipper = insert(:shipper)

      %{id: doc_id} = insert(:agreement_document, support_documents: [build(:agreement_document)])

      assert {:error, {:agreement, ^doc_id},
              %Changeset{errors: [agreed: {_, [validation: :has_agreed]}]},
              _} = Accounts.accept_agreements(shipper, [])
    end
  end

  describe "build_user_agreement_attrs" do
    test "builds rejected user agreements when no agreements are specified" do
      %{id: document_id} =
        insert(:agreement_document, support_documents: [build(:agreement_document)])

      assert {[
                %{document_id: ^document_id, updated_at: _, agreed: false}
              ], _} = Accounts.build_user_agreement_attrs(:shipper, [])
    end

    test "automatically agrees to support document agreements" do
      %{id: document_id, support_documents: [%{id: support_document_id}]} =
        insert(:agreement_document, support_documents: [build(:agreement_document)])

      assert {[
                %{document_id: ^document_id, updated_at: ~N[2020-01-01 00:00:00], agreed: true},
                %{
                  document_id: ^support_document_id,
                  updated_at: ~N[2020-01-01 00:00:00],
                  agreed: true
                }
              ],
              _} =
               Accounts.build_user_agreement_attrs(:shipper, [
                 %{document_id: document_id, agreed: true, updated_at: ~N[2020-01-01 00:00:00]}
               ])
    end

    test "builds on top of existing user agreement" do
      driver = insert(:driver)

      %{id: document_id, support_documents: [%{id: support_document_id} = support_document]} =
        document =
        insert(:agreement_document,
          user_types: [:driver],
          support_documents: [build(:agreement_document, user_types: [:driver])]
        )

      %{id: agreement_id} =
        insert(:user_agreement,
          document: document,
          user: driver.user,
          updated_at: ~N[2020-01-01 00:00:00]
        )

      %{id: support_agreement_id} =
        insert(:user_agreement,
          document: support_document,
          user: driver.user,
          updated_at: ~N[2020-01-01 00:00:00]
        )

      assert {[
                %{
                  id: ^agreement_id,
                  document_id: ^document_id,
                  updated_at: updated_at,
                  agreed: true
                },
                %{
                  id: ^support_agreement_id,
                  document_id: ^support_document_id,
                  updated_at: support_updated_at,
                  agreed: true
                }
              ],
              _} =
               Accounts.build_user_agreement_attrs(driver, [
                 %{document_id: document_id, agreed: true, updated_at: ~N[2021-01-01 00:00:00]}
               ])

      assert updated_at == ~N[2021-01-01 00:00:00]
      assert support_updated_at == ~N[2021-01-01 00:00:00]
    end

    test "ignores support documents when agreement is rejected" do
      %{id: document_id} =
        insert(:agreement_document, support_documents: [build(:agreement_document)])

      assert {[
                %{document_id: ^document_id, updated_at: ~N[2020-01-01 00:00:00], agreed: false}
              ],
              _} =
               Accounts.build_user_agreement_attrs(:shipper, [
                 %{document_id: document_id, agreed: false, updated_at: ~N[2020-01-01 00:00:00]}
               ])
    end
  end

  describe "normalize_email_attrs/1" do
    test "It does not fail when no params are received" do
      attrs = nil
      normalized = Accounts.normalize_email_attrs(attrs)

      assert normalized == attrs
    end

    test "It does not fail when the email key is not present" do
      attrs = %{password: "reallyhardpasstoguess"}
      normalized = Accounts.normalize_email_attrs(attrs)

      assert normalized == attrs
    end

    test "given an email written entirely in uppercase, the domain part is converted to lowercase" do
      attrs = %{email: "TEST@TEST.COM"}
      normalized = Accounts.normalize_email_attrs(attrs)

      assert normalized == %{email: "TEST@test.com"}
    end

    test "given an email, the local part is converted neither upper nor lower case" do
      attrs = %{email: "TeSt@TEST.COM"}
      normalized = Accounts.normalize_email_attrs(attrs)

      assert normalized == %{email: "TeSt@test.com"}
    end
  end
end
