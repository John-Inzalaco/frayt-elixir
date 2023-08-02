defmodule FraytElixir.DataTableTest do
  import FraytElixirWeb.DataTable
  import FraytElixir.Factory
  use FraytElixir.DataCase

  describe "get_queried_url/3" do
    test "gets data from module and returns url" do
      assert "matches?order=desc&query=test" ==
               get_queried_url(
                 %{query: "test", order: :desc},
                 %{query: "", order: :asc},
                 "matches"
               )
    end

    test "returns nil when base_url is nil" do
      refute get_queried_url(%{query: "test", order: :desc}, %{}, nil)
    end

    test "converts params to url" do
      assert "matches?search=test" ==
               get_queried_url(
                 %{search: "test", order: :desc},
                 %{search: "", order: :desc, order_by: :name},
                 "matches"
               )
    end
  end
end
