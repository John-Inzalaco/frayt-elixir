defmodule FraytElixirWeb.CreateMultistopLiveTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixirWeb.Admin.CreateMultistopLive
  alias FraytElixirWeb.DisplayFunctions

  describe "liveview functions" do
    test "calculate_next_datetime" do
      datetime1 =
        calculate_next_datetime(
          {:thursday, ~T[19:12:00]},
          ~U[2020-10-22 10:12:32Z],
          "America/New_York"
        )

      datetime2 =
        calculate_next_datetime(
          {:friday, ~T[19:12:00]},
          ~U[2020-10-22 10:12:32Z],
          "America/New_York"
        )

      datetime3 =
        calculate_next_datetime(
          {:friday, ~T[02:12:00]},
          ~U[2020-10-22 10:12:32Z],
          "America/New_York"
        )

      DisplayFunctions.timezone_abbr_from_full(~U[2020-10-22 10:12:32Z], "America/New_York")
      |> case do
        "EST" ->
          assert datetime1 == [
                   {"Thursday, 10/22/2020 02:12:00 PM EST", ~U[2020-10-22 19:12:00Z]},
                   {"Thursday, 10/29/2020 02:12:00 PM EST", ~U[2020-10-29 19:12:00Z]}
                 ]

          assert datetime2 == [{"Friday, 10/23/2020 02:12:00 PM EST", ~U[2020-10-23 19:12:00Z]}]

          assert datetime3 == [{"Friday, 10/23/2020 09:12:00 PM EST", ~U[2020-10-23 02:12:00Z]}]

        "EDT" ->
          assert datetime1 == [
                   {"Thursday, 10/22/2020 03:12:00 PM EDT", ~U[2020-10-22 19:12:00Z]},
                   {"Thursday, 10/29/2020 03:12:00 PM EDT", ~U[2020-10-29 19:12:00Z]}
                 ]

          assert datetime2 == [{"Friday, 10/23/2020 03:12:00 PM EDT", ~U[2020-10-23 19:12:00Z]}]

          assert datetime3 == [{"Friday, 10/23/2020 10:12:00 PM EDT", ~U[2020-10-23 02:12:00Z]}]
      end
    end

    test "create_pickup_options" do
      %{location_id: location_id} =
        insert(:schedule,
          monday: ~T[12:23:00],
          thursday: ~T[18:23:00],
          friday: ~T[02:23:00],
          tuesday: nil,
          wednesday: nil,
          saturday: nil,
          sunday: nil
        )

      options = create_pickup_options(location_id, "America/New_York", ~U[2020-10-22 12:10:23Z])

      DisplayFunctions.timezone_abbr_from_full(~U[2020-10-22 12:10:23Z], "America/New_York")
      |> case do
        "EST" ->
          assert options == [
                   {"Thursday, 10/22/2020 01:23:00 PM EST", ~U[2020-10-22T18:23:00Z]},
                   {"Friday, 10/23/2020 09:23:00 PM EST", ~U[2020-10-23T02:23:00Z]},
                   {"Monday, 10/26/2020 07:23:00 AM EST", ~U[2020-10-26T12:23:00Z]},
                   {"Thursday, 10/29/2020 01:23:00 PM EST", ~U[2020-10-29T18:23:00Z]}
                 ]

        "EDT" ->
          assert options == [
                   {"Thursday, 10/22/2020 02:23:00 PM EDT", "2020-10-22T18:23:00Z"},
                   {"Friday, 10/23/2020 10:23:00 PM EDT", "2020-10-23T02:23:00Z"},
                   {"Monday, 10/26/2020 08:23:00 AM EDT", "2020-10-26T12:23:00Z"},
                   {"Thursday, 10/29/2020 02:23:00 PM EDT", "2020-10-29T18:23:00Z"}
                 ]
      end
    end
  end
end
