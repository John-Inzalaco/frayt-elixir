defmodule FraytElixirWeb.CompanyViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixir.Accounts.{Company, Location, Shipper}
  alias FraytElixir.Shipment.Match
  alias FraytElixirWeb.Admin.CompaniesView

  @company %Company{
    locations: [
      %Location{
        shippers: [
          %Shipper{
            matches: [
              %Match{}
            ]
          }
        ]
      },
      %Location{
        shippers: [
          %Shipper{
            matches: [
              %Match{}
            ]
          },
          %Shipper{
            matches: [
              %Match{}
            ]
          },
          %Shipper{
            matches: [
              %Match{}
            ]
          }
        ]
      },
      %Location{
        shippers: [
          %Shipper{
            matches: [
              %Match{},
              %Match{},
              %Match{}
            ]
          },
          %Shipper{
            matches: [
              %Match{},
              %Match{}
            ]
          },
          %Shipper{
            matches: [
              %Match{},
              %Match{},
              %Match{},
              %Match{}
            ]
          }
        ]
      },
      %Location{
        shippers: [
          %Shipper{
            matches: []
          }
        ]
      }
    ]
  }

  describe "companies view functions" do
    test "shipper_count" do
      assert CompaniesView.shipper_count(@company.locations) == 8
    end

    test "match_count" do
      assert CompaniesView.match_count(@company.locations) == 13
    end
  end
end
