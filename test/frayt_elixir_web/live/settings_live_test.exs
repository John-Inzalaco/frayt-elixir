defmodule FraytElixirWeb.SettingsLiveTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixir.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias FraytElixir.Accounts

  setup [:login_as_admin]

  describe "profile live" do
    test "non-changeset password errors: new and confirm match", %{
      conn: conn
    } do
      insert(:admin_user, user: build(:user, password: "p@ssw0rd"))
      conn = get(conn, "/admin/settings/profile")
      {:ok, view, html} = live(conn)
      assert html =~ "<h4>My Profile</h4>"
      profile_view = find_live_child(view, "profile")

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "password",
          "new_password" => "p@ssw0rd",
          "confirm_password" => "p@ssw0rds"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      assert result_view =~ "Passwords must match"

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "password",
          "new_password" => "p@ssw0rd",
          "confirm_password" => "p@ssw0rd"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      refute result_view =~ "Passwords must match"
      assert result_view =~ "Password changed"
    end

    test "reset password", %{conn: conn} do
      conn = get(conn, "/admin/settings/profile")
      {:ok, view, html} = live(conn)
      assert html =~ "<h4>My Profile</h4>"
      assert html =~ "<p>Admin User</p>"
      profile_view = find_live_child(view, "profile")

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      assert result_view =~ "<li class=\"error\">Please enter the old password"
      assert result_view =~ "<li class=\"error\">Please enter a new password"

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "password",
          "new_password" => "asd",
          "confirm_password" => "asd"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      assert result_view =~ "<li class=\"error\">must contain at least 8 characters"
      assert result_view =~ "<li class=\"error\">must contain a special character"
      assert result_view =~ "<li class=\"error\">must contain a number"
      refute result_view =~ "<li class=\"error\">Please enter a new password"

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "password",
          "new_password" => "asdfasdf",
          "confirm_password" => "asdfasdf"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      refute result_view =~ "<li class=\"error\">must contain at least 8 characters"
      assert result_view =~ "<li class=\"error\">must contain a special character"
      assert result_view =~ "<li class=\"error\">must contain a number"

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "password",
          "new_password" => "asd1asdf",
          "confirm_password" => "asd1asdf"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      refute result_view =~ "<li class=\"error\">must contain at least 8 characters"
      assert result_view =~ "<li class=\"error\">must contain a special character"
      refute result_view =~ "<li class=\"error\">must contain a number"

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "test",
          "new_password" => "asd1asdf",
          "confirm_password" => "asd1asdf"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      assert result_view =~ "<li class=\"error\">Invalid old password"

      profile_view
      |> element("[data-test-id='password-form']")
      |> render_change(%{
        "password_form" => %{
          "old_password" => "password",
          "new_password" => "asd1@sdf",
          "confirm_password" => "asd1@sdf"
        }
      })

      result_view =
        profile_view
        |> element("[data-test-id='password-form']")
        |> render_submit

      refute result_view =~ "<li class=\"error\">must contain at least 8 characters"
      refute result_view =~ "<li class=\"error\">must contain a special character"
      refute result_view =~ "<li class=\"error\">must contain a number"
      assert result_view =~ "Password changed"
    end
  end

  describe "invite live" do
    test "invite users cancel clears form", %{conn: conn} do
      insert(:admin_user, user: build(:user, password: "p@ssw0rd"))
      conn = get(conn, "/admin/settings/profile")
      {:ok, view, html} = live(conn)
      assert html =~ "<h4>My Profile</h4>"

      result =
        view
        |> element("[data-test-id='users-tab']")
        |> render_click

      assert result =~ "<h4>Invite Users</h4>"
      refute result =~ "<h4>My Profile</h4>"
      invite_view = find_live_child(view, "users")

      invite_view
      |> element("[data-test-id='invite-form']")
      |> render_change(%{
        "_target" => ["invite_admin_form", "email"],
        "admin_user" => %{
          "user" => %{"email" => "some@email.com"},
          "role" => :admin,
          "name" => nil
        }
      })

      result =
        invite_view
        |> element("[data-test-id='cancel-invite']")
        |> render_click

      refute result =~ "value=\"some@email.com\""
      refute result =~ "value=\"admin\" selected=\"selected\""
    end

    test "invite users", %{conn: conn} do
      admin =
        insert(:admin_user,
          name: "Initial Admin",
          user: build(:user, email: "admin@email.com", password: "p@ssw0rd")
        )

      conn = get(conn, "/admin/settings/profile")
      {:ok, view, html} = live(conn)
      assert html =~ "<h4>My Profile</h4>"

      result =
        view
        |> element("[data-test-id='users-tab']")
        |> render_click

      assert result =~ "<h4>Invite Users</h4>"
      refute result =~ "<h4>My Profile</h4>"
      invite_view = find_live_child(view, "users")

      admins = Accounts.list_admins()
      assert Enum.count(admins) == 2

      users = Accounts.list_users()
      assert Enum.count(users) == 2

      assert Enum.find(admins, &(&1.id == admin.id))
      assert Enum.find(users, &(&1.id == admin.user.id))

      invite_view
      |> element("[data-test-id='invite-form']")
      |> render_change(%{
        "_target" => ["invite_admin_form", "email"],
        "admin_user" => %{
          "user" => %{"email" => "some@email.com"},
          "role" => "member",
          "name" => "Some"
        }
      })

      result =
        invite_view
        |> element("[data-test-id='invite-form']")
        |> render_submit

      refute result =~ "value=\"some@email.com\""
      refute result =~ "value=\"admin\" selected=\"selected\""
      assert "<td>Initial Admin <span class=\"caption\">admin@email.com</span></td><td>Admin</td>"
      assert "<td>User 2 <span class=\"caption\">some@email.com</span></td><td>Admin</td>"

      assert "<td>User 3 <span class=\"caption\">someother@email.com</span></td><td>Member</td>"

      admins =
        Accounts.list_admins()
        |> Enum.map(& &1.role)

      users = Accounts.list_users() |> Enum.map(& &1.email)

      assert [_random] = users -- ["admin@email.com", "some@email.com"]
      assert Enum.count(admins) == 3
      assert Enum.count(users) == 3
      assert Enum.sort(admins) == [:admin, :admin, :member]
    end

    test "invite users error messages", %{conn: conn} do
      admin =
        insert(:admin_user,
          name: "Initial Admin",
          user: build(:user, email: "some@email.com", password: "p@ssw0rd")
        )

      conn = get(conn, "/admin/settings/profile")
      {:ok, view, html} = live(conn)
      assert html =~ "<h4>My Profile</h4>"

      result =
        view
        |> element("[data-test-id='users-tab']")
        |> render_click

      assert result =~ "<h4>Invite Users</h4>"
      refute result =~ "<h4>My Profile</h4>"
      invite_view = find_live_child(view, "users")

      admins = Accounts.list_admins()
      # Two already existing admins
      assert Enum.count(admins) == 2

      users = Accounts.list_users()
      # Three already existing admins
      assert Enum.count(users) == 2

      assert Enum.find(admins, &(&1.id == admin.id))
      assert Enum.find(users, &(&1.id == admin.user.id))

      invite_view
      |> element("[data-test-id='invite-form']")
      |> render_change(%{
        "_target" => ["invite_admin_form", "email"],
        "admin_user" => %{
          "user" => %{"email" => "some@email.com"},
          "role" => :admin,
          "name" => "Some Name"
        }
      })

      result =
        invite_view
        |> element("[data-test-id='invite-form']")
        |> render_submit

      assert result =~ "has already been taken."

      admins = Accounts.list_admins()
      users = Accounts.list_users() |> Enum.map(& &1.email)

      assert "some@email.com" in users

      assert Enum.count(admins) == 2
      assert Enum.count(users) == 2
    end
  end

  describe "contract slas" do
    setup do
      %{contract: insert(:contract)}
    end

    test "should print all SLA type names as labels when contract SLAs are listed", params do
      %{conn: conn, contract: contract} = params
      conn = get(conn, "/admin/settings/contracts/#{contract.id}")
      {:ok, view, _html} = live(conn)

      assert element(view, "[data-test-id='acceptance-sla-type-label']") |> render() =~
               "Acceptance"

      assert element(view, "[data-test-id='pickup-sla-type-label']") |> render() =~ "Pickup"
      assert element(view, "[data-test-id='delivery-sla-type-label']") |> render() =~ "Delivery"
    end

    test "should print `Default` in place of duration for not yet defined SLAs when contract SLAs are listed",
         params do
      %{conn: conn, contract: contract} = params
      conn = get(conn, "/admin/settings/contracts/#{contract.id}")
      {:ok, view, _html} = live(conn)

      assert element(view, "[data-test-id='acceptance-sla-duration-label']") |> render() =~
               "Default"

      assert element(view, "[data-test-id='pickup-sla-duration-label']") |> render() =~ "Default"

      assert element(view, "[data-test-id='delivery-sla-duration-label']") |> render() =~
               "Default"
    end

    test "should print the duration per each SLA that is already defined when contract SLAs are listed",
         params do
      %{conn: conn, contract: contract} = params

      pickup_sla =
        insert(:contract_sla, contract: contract, type: :pickup, duration: "stop_count*2")

      delivery_sla =
        insert(:contract_sla, contract: contract, type: :delivery, duration: "total_distance/2")

      conn = get(conn, "/admin/settings/contracts/#{contract.id}")
      {:ok, view, _html} = live(conn)

      assert element(view, "[data-test-id='acceptance-sla-duration-label']") |> render() =~
               "Default"

      assert element(view, "[data-test-id='pickup-sla-duration-label']") |> render() =~
               pickup_sla.duration

      assert element(view, "[data-test-id='delivery-sla-duration-label']") |> render() =~
               delivery_sla.duration
    end

    test "should display SLA type names as labels when contract SLAs are being edited", params do
      %{conn: conn, contract: contract} = params
      conn = get(conn, "/admin/settings/contracts/#{contract.id}")
      {:ok, view, _html} = live(conn)

      assert element(view, "[data-test-id='acceptance-sla-type-label']") |> render() =~
               "Acceptance"

      assert element(view, "[data-test-id='pickup-sla-type-label']") |> render() =~ "Pickup"
      assert element(view, "[data-test-id='delivery-sla-type-label']") |> render() =~ "Delivery"
    end
  end
end
