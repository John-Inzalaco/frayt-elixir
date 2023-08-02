defmodule FraytElxir.MapKeysTest do
  use ExUnit.Case
  alias FraytElixir.Utils
  alias ExPhoneNumber.Model.PhoneNumber

  test "map keys maps the keys in the map with the map of keys" do
    assert Utils.map_keys(%{a: "b", b: "a"}, %{a: :b, b: :a, c: :d}) == %{b: "b", a: "a"}
  end

  describe "maybe_parse_phone" do
    test "can parse to PhoneNumber" do
      assert %PhoneNumber{country_code: 1, national_number: 5_134_027_050} =
               Utils.maybe_parse_phone("+15134027050")

      assert %PhoneNumber{country_code: 1, national_number: 5_134_027_050} =
               Utils.maybe_parse_phone("5134027050")

      assert %PhoneNumber{country_code: 1, national_number: 5_134_027_050} =
               Utils.maybe_parse_phone("15134027050")
    end

    test "returns nil for nil" do
      assert nil == Utils.maybe_parse_phone(nil)
    end

    test "returns unparsable value" do
      assert "1234" == Utils.maybe_parse_phone("1234")
    end
  end
end
