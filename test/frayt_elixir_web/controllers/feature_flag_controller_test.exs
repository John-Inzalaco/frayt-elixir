defmodule FraytElixirWeb.API.Internal.FeatureFlagControllerTest do
  use FraytElixirWeb.ConnCase

  describe "show" do
    setup context do
      if Map.get(context, :skip_user_login), do: {:ok, context}, else: login_as_user(context)
    end

    test "returns true when flag is enabled for user", %{conn: conn, user: user} do
      FunWithFlags.enable(:test_flag, for_actor: user)

      assert %{"enabled" => true} =
               conn
               |> get(Routes.api_v2_feature_flag_path(conn, :show, ".1", flag: "test_flag"))
               |> json_response(200)
    end

    test "returns false when flag is disabled for user", %{conn: conn, user: user} do
      FunWithFlags.disable(:test_flag, for_actor: user)

      assert %{"enabled" => false} =
               conn
               |> get(Routes.api_v2_feature_flag_path(conn, :show, ".1", flag: "test_flag"))
               |> json_response(200)
    end

    test "returns false when flag does not exist", %{conn: conn} do
      assert %{"enabled" => false} =
               conn
               |> get(Routes.api_v2_feature_flag_path(conn, :show, ".1", flag: "invalid_flag"))
               |> json_response(200)
    end

    test "returns false when no flag is specified", %{conn: conn} do
      assert %{"enabled" => false} =
               conn
               |> get(Routes.api_v2_feature_flag_path(conn, :show, ".1"))
               |> json_response(200)
    end

    @tag skip_user_login: true
    test "returns 401 when no authorized user exists", %{conn: conn} do
      conn
      |> get(Routes.api_v2_feature_flag_path(conn, :show, ".1", flag: "test_flag"))
      |> json_response(401)
    end
  end
end
