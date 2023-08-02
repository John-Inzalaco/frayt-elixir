defmodule FraytElixir.Import.ImportTest do
  use FraytElixir.DataCase
  alias FraytElixir.Import

  describe "convert_to_map_list/1" do
    test "converst csv data into a map with header row keys" do
      assert [
               %{"Name" => "Some Dude", "Address" => "555 Nowhere St"},
               %{"Name" => "Another Tester", "Address" => "123 Poplar St"},
               %{"Name" => "Nomadic Person", "Address" => ""}
             ] ==
               Import.convert_to_map_list([
                 {:ok, ["Name", "Address"]},
                 {:ok, ["Some Dude", "555 Nowhere St"]},
                 {:ok, ["Another Tester", "123 Poplar St"]},
                 {:ok, ["Nomadic Person", ""]}
               ])
    end
  end

  describe "convert_to_integer/1" do
    test "converts integer string to integer" do
      assert 100 == Import.convert_to_integer("100")
    end

    test "converts with commas to integer" do
      assert 1000 == Import.convert_to_integer("1,000")
    end

    test "converts float string to integer" do
      assert 100 == Import.convert_to_integer("100.2")
    end

    test "rounds float string to integer" do
      assert 101 == Import.convert_to_integer("100.5")
    end
  end
end
