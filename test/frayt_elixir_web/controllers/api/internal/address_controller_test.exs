defmodule FraytElixirWeb.API.Internal.AddressControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper

  describe "index" do
    setup [:login_as_shipper]

    test "lists all matches", %{conn: conn, shipper: shipper} do
      insert(:match,
        shipper: shipper,
        origin_address:
          build(:address, formatted_address: "7285 Dixie Highway, Fairfield, OH, USA")
      )

      conn = get(conn, Routes.api_v2_address_path(conn, :index, ".1"))
      addresses = json_response(conn, 200)["response"]
      assert Enum.count(addresses) == 2
    end
  end
end
