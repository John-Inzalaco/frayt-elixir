defmodule FraytElixir.ConvertTest do
  use FraytElixir.DataCase
  alias FraytElixir.Convert

  describe "to_boolean" do
    test "keeps bool" do
      assert Convert.to_boolean(true) == true
    end

    test "converts string to bool" do
      assert Convert.to_boolean("false") == false
      assert Convert.to_boolean("true") == true
      assert Convert.to_boolean("adfsa") == false
    end
  end

  describe "to_integer" do
    test "keeps integer" do
      assert Convert.to_integer(1) == 1
    end

    test "converts and floors float" do
      assert Convert.to_integer(2.1) == 2
      assert Convert.to_integer(2.8) == 2
    end

    test "converts and floors string" do
      assert Convert.to_integer("3") == 3
      assert Convert.to_integer("2.1") == 2
      assert Convert.to_integer("2.8") == 2
    end

    test "falls back to default for invalid value" do
      assert Convert.to_integer("e1", 2) == 2
      assert Convert.to_integer(:a, 2) == 2
    end
  end

  describe "to_float" do
    test "keeps float" do
      assert Convert.to_float(1.2) == 1.2
    end

    test "converts integer" do
      assert Convert.to_float(2) == 2.0
    end

    test "converts string" do
      assert Convert.to_float("3") == 3.0
      assert Convert.to_float("2.1") == 2.1
    end

    test "falls back to default for invalid string" do
      assert Convert.to_float("e1", 2.0) == 2.0
      assert Convert.to_float(:a, 2.0) == 2.0
    end
  end

  describe "to_string" do
    test "keeps string" do
      assert Convert.to_string("string") == "string"
    end

    test "converts atom" do
      assert Convert.to_string(:string) == "string"
    end

    test "converts integer" do
      assert Convert.to_string(1) == "1"
    end

    test "converts float" do
      assert Convert.to_string(1.2) == "1.2"
    end
  end

  describe "to_atom" do
    test "keeps atom" do
      assert Convert.to_atom(:atom) == :atom
    end

    test "converts string" do
      assert Convert.to_atom("atom") == :atom
    end

    test "returns string for new atom" do
      assert Convert.to_atom("azqwsxecdrfvtbgyhnujmiko") == "azqwsxecdrfvtbgyhnujmiko"
    end
  end

  describe "to_list" do
    test "keeps list" do
      assert Convert.to_list([1, :a]) == [1, :a]
    end

    test "converts list to list of integers" do
      assert Convert.to_list([1, 2.4, :a, -4.5], :integer) == [1, 2, -5]
    end

    test "converts string to list" do
      assert Convert.to_list("a,b,c ,d") == ["a", "b", "c ", "d"]
    end

    test "converts string to list of floats" do
      assert Convert.to_list("a,1.2,1 ,-3", :float) == [1.2, 1.0, -3.0]
    end

    test "returns empty string on fail" do
      assert Convert.to_list(1) == []
    end
  end

  describe "value_or_nil" do
    test "returns value" do
      assert Convert.value_or_nil("3") == "3"
    end
  end
end
