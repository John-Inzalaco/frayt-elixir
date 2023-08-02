defmodule FraytElixirWeb.API.Internal.UserControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.User

  @create_attrs %{
    email: "some@email.com",
    password: "somesupersecretstuff"
  }
  @update_attrs %{
    email: "some_updated@email.com"
  }
  @invalid_attrs %{email: nil, hashed_password: nil}

  def fixture(:user) do
    {:ok, user} = Accounts.create_user(@create_attrs)
    user
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup [:create_user, :login]

    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.api_v2_user_path(conn, :index, ".1"))
      users = json_response(conn, 200)["data"]
      assert Enum.count(users) == 1
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.api_v2_user_path(conn, :create, ".1"), user: @create_attrs)
      assert %{"id" => _} = json_response(conn, 201)["response"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.api_v2_user_path(conn, :create, ".1"), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "get user" do
    setup [:create_user, :login]

    test "get user returns user data", %{conn: conn, user: user} do
      conn = get(conn, Routes.api_v2_user_path(conn, :show, ".1", user.id))

      assert %{
               "id" => _,
               "email" => "some@email.com"
             } = json_response(conn, 200)["response"]
    end
  end

  describe "update user" do
    setup [:create_user, :login]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn =
        conn
        |> put(Routes.api_v2_user_path(conn, :update, ".1", user), user: @update_attrs)

      assert %{"id" => ^id} = json_response(conn, 200)["response"]

      conn = get(conn, Routes.api_v2_user_path(conn, :show, ".1", id))

      assert %{
               "id" => _,
               "email" => "some_updated@email.com"
             } = json_response(conn, 200)["response"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, Routes.api_v2_user_path(conn, :update, ".1", user), user: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "forgot password" do
    setup [:create_user, :login]

    test "returns 200 status with valid email", %{conn: conn, user: %User{email: email}} do
      conn = post(conn, Routes.api_v2_user_path(conn, :forgot_password, ".1"), %{email: email})

      assert response(conn, 200)
    end

    test "returns 200 status with invalid email", %{conn: conn} do
      conn =
        post(conn, Routes.api_v2_user_path(conn, :forgot_password, ".1"), %{
          email: "not_a_real@frayt_user.com"
        })

      assert response(conn, 200)
    end
  end

  describe "reset password" do
    setup [:create_user, :login]

    test "returns 200 if correct code is passed", %{conn: conn, user: %User{email: email, id: id}} do
      Accounts.forgot_password(email)
      %User{password_reset_code: code} = Accounts.get_user!(id)

      conn =
        post(conn, Routes.api_v2_user_path(conn, :reset_password, ".1"), %{
          "password_reset_code" => code,
          "password" => "password1!",
          "password_confirmation" => "password1!"
        })

      assert response(conn, 200)
    end

    test "returns 403 if incorrect code is passed", %{conn: conn, user: %User{email: email}} do
      Accounts.forgot_password(email)

      conn =
        post(conn, Routes.api_v2_user_path(conn, :reset_password, ".1"), %{
          "password_reset_code" => "boguscode",
          "password" => "password1!",
          "password_confirmation" => "password1!"
        })

      assert response(conn, 403)
    end

    test "returns password rule error if invalid password is passed", %{
      conn: conn,
      user: %User{email: email, id: id}
    } do
      Accounts.forgot_password(email)
      %User{password_reset_code: code} = Accounts.get_user!(id)

      conn =
        post(conn, Routes.api_v2_user_path(conn, :reset_password, ".1"), %{
          "password_reset_code" => code,
          "password" => "password1",
          "password_confirmation" => "password1"
        })

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  defp create_user(_) do
    user = fixture(:user)
    {:ok, user: user}
  end

  defp login(%{user: user, conn: conn}) do
    {:ok, token, _} = encode_and_sign(user)

    conn =
      conn
      |> put_req_header("authorization", "bearer: " <> token)

    {:ok, conn: conn}
  end
end
