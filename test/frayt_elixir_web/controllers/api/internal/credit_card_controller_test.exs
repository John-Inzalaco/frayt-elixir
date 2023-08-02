defmodule FraytElixirWeb.API.Internal.CreditCardControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Payments

  import FraytElixirWeb.Test.LoginHelper

  @create_attrs %{
    stripe_card: "some stripe_card",
    stripe_token: "some stripe_token"
  }
  @invalid_attrs %{stripe_card: nil, stripe_token: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create credit_card" do
    setup [:login_as_shipper]

    test "renders credit_card when data is valid", %{conn: conn, shipper: shipper} do
      conn = post(conn, Routes.api_v2_credit_card_path(conn, :create, ".1"), @create_attrs)
      assert %{"credit_card" => last4} = json_response(conn, 201)["response"]

      {:ok, created_card} = Payments.get_credit_card_for_shipper(shipper)
      assert created_card.last4 == last4
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.api_v2_credit_card_path(conn, :create, ".1"), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "get credit card" do
    setup [:login_as_shipper, :create_credit_card]

    test "get credit card for logged in shipper", %{conn: conn, credit_card: credit_card} do
      conn = get(conn, Routes.api_v2_credit_card_path(conn, :show, ".1"))
      assert %{"credit_card" => last4} = json_response(conn, 200)["response"]
      assert last4 == credit_card.last4
    end
  end

  def create_credit_card(context) do
    {:ok, credit_card} =
      Payments.create_credit_card(@create_attrs |> Map.put(:shipper, context.shipper))

    {:ok, credit_card: credit_card}
  end
end
