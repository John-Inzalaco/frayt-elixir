defmodule FraytElixirWeb.CreateUpdateCompanyTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixirWeb.CreateUpdateCompany

  describe "edit company/location functions" do
    test "maybe_replace_sales_rep when shipper/location sales rep exists" do
      assert maybe_replace_sales_rep(
               %{"replace_sales_rep" => "true", "sales_rep_id" => "12345"},
               %{sales_rep_id: "54321"}
             ) == "12345"

      assert maybe_replace_sales_rep(
               %{"replace_sales_rep" => "false", "sales_rep_id" => "12345"},
               %{sales_rep_id: "54321"}
             ) == "54321"
    end

    test "maybe_replace_sales_rep when shipper/location sales rep doesn't exist" do
      assert maybe_replace_sales_rep(
               %{"replace_sales_rep" => "true", "sales_rep_id" => "12345"},
               %{sales_rep_id: nil}
             ) == "12345"

      assert maybe_replace_sales_rep(
               %{"replace_sales_rep" => "false", "sales_rep_id" => "12345"},
               %{sales_rep_id: nil}
             ) == nil
    end

    test "shipper_replacement" do
      assert shipper_replacement(
               %{"replace_sales_rep" => "true", "sales_rep_id" => "12345"},
               [%{id: "1", sales_rep_id: "54321"}, %{id: "2", sales_rep_id: nil}]
             ) == [%{id: "1", sales_rep_id: "12345"}, %{id: "2", sales_rep_id: "12345"}]

      assert shipper_replacement(
               %{"replace_sales_rep" => "true", "sales_rep_id" => "12345"},
               []
             ) == []

      assert shipper_replacement(
               %{"replace_sales_rep" => "false", "sales_rep_id" => "12345"},
               [%{id: "1", sales_rep_id: "54321"}, %{id: "2", sales_rep_id: nil}]
             ) == [%{id: "1", sales_rep_id: "12345"}, %{id: "2", sales_rep_id: "12345"}]
    end

    test "maybe_replace_invoice_period" do
      assert maybe_replace_invoice_period(
               %{"replace_invoice_period" => "true", "invoice_period" => 12},
               %{invoice_period: nil}
             ) == 12

      assert maybe_replace_invoice_period(
               %{"replace_invoice_period" => "false", "invoice_period" => 12},
               %{invoice_period: nil}
             ) == nil

      assert maybe_replace_invoice_period(
               %{"replace_invoice_period" => "true", "invoice_period" => 12},
               %{invoice_period: 32}
             ) == 12

      assert maybe_replace_invoice_period(
               %{"replace_invoice_period" => "false", "invoice_period" => 12},
               %{invoice_period: 25}
             ) == 25
    end
  end
end
