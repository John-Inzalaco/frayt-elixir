defmodule FraytElixir.Workers.CompanyMetricsUpdaterTest do
  use FraytElixir.DataCase

  import FraytElixir.Factory

  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Workers.CompanyMetricsUpdater

  test "updates company metrics" do
    FakeSlack.clear_messages()

    insert_list(51, :driver)
    [company1, company2, _company3] = insert_list(3, :company)
    [location1, location2, _location3] = insert_list(3, :location, company: company1)
    [location4, _location5] = insert_list(2, :location, company: company2)
    [shipper1, shipper2] = insert_list(2, :shipper, location: location1)
    [shipper3, _shipper4] = insert_list(2, :shipper, location: location2)
    shipper5 = insert(:shipper, location: location4)
    insert_list(5, :match, shipper: shipper1, amount_charged: 10_00, state: :completed)
    insert_list(2, :match, shipper: shipper2, amount_charged: 20_00, state: :completed)
    insert_list(3, :match, shipper: shipper3, amount_charged: nil, state: :pending)
    insert_list(7, :match, shipper: shipper5, amount_charged: 500_00, state: :completed)
    CompanyMetricsUpdater.perform("")

    assert [
             {"#test-appsignal", "Finished updating 2 company metrics after 0 seconds"},
             {"#test-appsignal", "Starting company aggregate update"}
           ] == FakeSlack.get_messages("#test-appsignal")

    assert [{0, 0}, {7, 9000}, {7, 350_000}] ==
             FraytElixir.Accounts.list_companies()
             |> Enum.sort_by(& &1.revenue, :asc)
             |> Enum.map(&{&1.match_count, &1.revenue})
  end
end
