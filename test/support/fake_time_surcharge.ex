defmodule FraytElixir.Test.FakeTimeSurcharge do
  alias FraytElixir.Shipment
  alias Shipment.Match
  alias FraytElixir.CustomContracts.DistanceTemplate

  def get_time_surcharge(%Match{scheduled: false} = match, opts) do
    date_time = Shipment.match_authorized_time(match) || DateTime.utc_now()

    case NaiveDateTime.compare(date_time, ~N[2020-12-31 23:59:59]) do
      :lt -> DistanceTemplate.get_time_surcharge(match, opts)
      _ -> 1.0
    end
  end

  def get_time_surcharge(match, opts),
    do: DistanceTemplate.get_time_surcharge(match, opts)
end
