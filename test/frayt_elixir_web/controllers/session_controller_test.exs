defmodule FraytElixirWeb.SessionControllerTest do
  use FraytElixirWeb.ConnCase

  describe "authenticate driver" do
    setup [:create_driver, :create_unregistered_driver]

    test "returns a valid JWT token", %{
      conn: conn,
      driver: %{
        first_name: first_name,
        last_name: last_name,
        user: %{email: email, id: user_id}
      }
    } do
      creds = %{
        email: email,
        password: "password"
      }

      conn = post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), creds)

      assert %{
               "token" => token,
               "driver" => %{
                 "email" => ^email,
                 "first_name" => ^first_name,
                 "last_name" => ^last_name,
                 "state" => "approved",
                 "is_password_set" => true
               }
             } = json_response(conn, 200)["response"]

      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)
      assert claims["sub"] == user_id
    end

    test "returns a valid JWT token with valid code", %{
      conn: conn,
      unregistered_driver: %{
        user: %{email: email, id: user_id, password_reset_code: code}
      }
    } do
      creds = %{
        email: email,
        code: code
      }

      conn = post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), creds)

      assert %{
               "token" => token,
               "driver" => %{
                 "email" => ^email
               }
             } = json_response(conn, 200)["response"]

      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)
      assert claims["sub"] == user_id
    end

    test "revoke all current tokens before getting a new one on email/password auth",
         %{
           conn: conn,
           driver: %{user: %{id: user_id, email: email} = user}
         } do
      creds = %{email: email, password: "password"}
      # Getting two tokens
      {:ok, token1, _claims} = FraytElixir.Guardian.encode_and_sign(user)
      {:ok, token2, _claims} = FraytElixir.Guardian.encode_and_sign(user)

      # Validating both tokens before a new login
      assert {:ok, claims1} = FraytElixir.Guardian.decode_and_verify(token1)
      assert {:ok, claims2} = FraytElixir.Guardian.decode_and_verify(token2)
      assert %{"exp" => _exp, "sub" => ^user_id} = claims1
      assert %{"exp" => _exp, "sub" => ^user_id} = claims2

      # New login
      conn = post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), creds)

      # New login ok
      assert %{"token" => token} = json_response(conn, 200)["response"]
      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)
      assert claims["sub"] == user_id

      # Validating token1 and token2 after a new login (they should be revoked)
      assert {:error, :token_not_found} = FraytElixir.Guardian.decode_and_verify(token1)
      assert {:error, :token_not_found} = FraytElixir.Guardian.decode_and_verify(token2)
    end

    test "driver token timeout should be 4 weeks by default on email/password auth",
         %{
           conn: conn,
           driver: %{user: %{email: email}}
         } do
      creds = %{email: email, password: "password"}
      conn = post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), creds)

      assert %{"token" => token} = json_response(conn, 200)["response"]
      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)

      four_weeks_later = System.system_time(:second) + 4 * 7 * 24 * 60 * 60

      assert four_weeks_later - claims["exp"] <= 1
    end

    test "revoke all current tokens before getting a new one on email/code auth",
         %{conn: conn, unregistered_driver: %{user: user}} do
      %{email: email, id: user_id, password_reset_code: code} = user
      creds = %{email: email, code: code}
      # Getting two tokens
      {:ok, token1, _claims} = FraytElixir.Guardian.encode_and_sign(user)
      {:ok, token2, _claims} = FraytElixir.Guardian.encode_and_sign(user)

      # Validating both tokens before a new login
      assert {:ok, claims1} = FraytElixir.Guardian.decode_and_verify(token1)
      assert {:ok, claims2} = FraytElixir.Guardian.decode_and_verify(token2)
      assert %{"exp" => _exp, "sub" => ^user_id} = claims1
      assert %{"exp" => _exp, "sub" => ^user_id} = claims2

      # New login
      conn = post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), creds)

      # New login ok
      assert %{"token" => token} = json_response(conn, 200)["response"]
      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)
      assert claims["sub"] == user_id

      # Validating token1 and token2 after a new login (they should be revoked)
      assert {:error, :token_not_found} = FraytElixir.Guardian.decode_and_verify(token1)
      assert {:error, :token_not_found} = FraytElixir.Guardian.decode_and_verify(token2)
    end

    test "driver token timeout should be 4 weeks by default on email/code auth",
         %{conn: conn, unregistered_driver: %{user: user}} do
      %{email: email, password_reset_code: code} = user
      creds = %{email: email, code: code}
      conn = post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), creds)

      assert %{"token" => token} = json_response(conn, 200)["response"]
      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)

      four_weeks_later = System.system_time(:second) + 4 * 7 * 24 * 60 * 60

      assert four_weeks_later - claims["exp"] <= 1
    end

    test "fails with invalid code failure", %{conn: conn, unregistered_driver: driver} do
      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), %{
          email: driver.user.email,
          code: "garbage"
        })

      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end

    test "fails with invalid password failure", %{conn: conn, driver: driver} do
      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), %{
          email: driver.user.email,
          password: "garbage"
        })

      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end

    test "fails with invalid credentials failure", %{conn: conn} do
      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), %{
          email: "grabage@trash.com",
          password: "garbage"
        })

      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end

    test "fails with no creds", %{conn: conn} do
      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), %{
          email: nil,
          password: nil
        })

      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end

    test "fails with wrong user type", %{conn: conn} do
      shipper = insert(:shipper)

      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_driver, ".1"), %{
          email: shipper.user.email,
          password: "password"
        })

      assert %{"code" => "invalid_user"} = json_response(conn, 403)
    end
  end

  describe "authenticate shipper" do
    setup [:create_user]

    test "authenticates and receives the JWT token", %{conn: conn, user: user} do
      insert(:shipper, user: user)

      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_shipper, ".1"), %{
          email: user.email,
          password: user.password
        })

      assert %{
               "token" => token
             } = json_response(conn, 200)["response"]

      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)
      assert claims["sub"] == user.id
    end

    test "authentication password failure", %{conn: conn} do
      conn =
        post(conn, Routes.api_v2_session_path(conn, :authenticate_shipper, ".1"), %{
          email: "some@email.com",
          password: "garbage"
        })

      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end
  end

  describe "logout api user" do
    setup [:create_user, :login_api]

    test "logout and invalidate token", %{conn: conn} do
      conn = delete(conn, Routes.api_v2_session_path(conn, :logout, ".1"))

      assert conn.status == 200
    end

    test "logout and invalidate token when token is invalid", %{conn: conn} do
      delete(conn, Routes.api_v2_session_path(conn, :logout, ".1"))

      conn =
        conn
        |> delete(Routes.api_v2_session_path(conn, :logout, ".1"))

      assert %{"code" => "invalid_token"} = json_response(conn, 401)
    end
  end

  describe "new/2" do
    test "confirm page renders", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :new))
      assert html_response(conn, 200) =~ "Password"
    end
  end

  describe "create/2" do
    setup [:create_admin_user]

    test "invalid password", %{conn: conn} do
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          session: %{email: "foo@example.com", password: "wrongP4ssw0rd"}
        })

      assert html_response(conn, 200) =~ "Invalid email/password"
    end

    test "invalid email", %{conn: conn} do
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          session: %{email: "test@example.com", password: "P4ssw0rd"}
        })

      assert html_response(conn, 200) =~ "Invalid email/password"
    end

    test "blank credentials", %{conn: conn} do
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          session: %{email: "", password: ""}
        })

      assert html_response(conn, 200) =~ "Invalid email/password"
    end

    test "logging out", %{conn: conn} do
      conn =
        conn
        |> post(Routes.session_path(conn, :create), %{
          session: %{email: "foo@example.com", password: "P4ssw0rd"}
        })
        |> delete(Routes.session_path(conn, :delete))

      assert redirected_to(conn, 302) =~ Routes.session_path(conn, :logged_out)
    end
  end

  describe "admin login redirects" do
    test "successful login redirects to match dashboard", %{conn: conn} do
      insert(:admin_user, user: build(:user, email: "test@example.com", password: "password"))

      conn =
        post(
          conn,
          Routes.session_path(conn, :create,
            session: %{"email" => "test@example.com", password: "password"}
          )
        )

      assert redirected_to(conn) == Routes.matches_path(conn, :index)
    end
  end

  defp create_admin_user(_) do
    admin_user =
      insert(:admin_user, user: build(:user, email: "foo@example.com", password: "P4ssw0rd$"))

    {:ok, admin_user: admin_user}
  end

  defp create_driver(_) do
    driver = insert(:driver)
    {:ok, driver: driver}
  end

  defp create_unregistered_driver(_) do
    driver = insert(:unregistered_driver)
    {:ok, unregistered_driver: driver}
  end

  defp create_user(_) do
    user = insert(:user)
    {:ok, user: user}
  end

  defp login_api(%{user: user, conn: conn}) do
    {:ok, token, _} = encode_and_sign(user)

    conn =
      conn
      |> put_req_header("authorization", "bearer: " <> token)

    {:ok, conn: conn}
  end
end
