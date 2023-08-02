defmodule FraytElixirWeb.AddCompanyLiveTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.AdminAddCompanyLive

  describe "liveview functions" do
    test "empty_location_with_sales_rep" do
      sales_rep = insert(:admin_user, role: "sales_rep")

      company1 =
        insert(:company, sales_rep: sales_rep, invoice_period: 12, account_billing_enabled: true)

      company2 =
        insert(:company, sales_rep_id: nil, account_billing_enabled: false, invoice_period: nil)

      assert AdminAddCompanyLive.empty_location_with_sales_rep_and_billing(company1.id) ==
               %{
                 location: %{
                   location: nil,
                   store_number: nil,
                   invoice_period: 12,
                   sales_rep_id: sales_rep.id,
                   email: nil,
                   account_billing_enabled: true,
                   replace_locations: nil
                 },
                 address: %{
                   address: nil,
                   address2: nil,
                   city: nil,
                   state: nil,
                   zip: nil
                 }
               }

      assert AdminAddCompanyLive.empty_location_with_sales_rep_and_billing(company2.id) ==
               %{
                 location: %{
                   location: nil,
                   store_number: nil,
                   invoice_period: nil,
                   sales_rep_id: nil,
                   email: nil,
                   account_billing_enabled: false,
                   replace_locations: nil
                 },
                 address: %{
                   address: nil,
                   address2: nil,
                   city: nil,
                   state: nil,
                   zip: nil
                 }
               }

      assert AdminAddCompanyLive.empty_location_with_sales_rep_and_billing(nil) ==
               %{
                 location: %{
                   location: nil,
                   store_number: nil,
                   invoice_period: nil,
                   sales_rep_id: nil,
                   email: nil,
                   account_billing_enabled: nil,
                   replace_locations: nil
                 },
                 address: %{
                   address: nil,
                   address2: nil,
                   city: nil,
                   state: nil,
                   zip: nil
                 }
               }
    end
  end
end
