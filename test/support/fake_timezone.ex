defmodule FraytElixir.Test.FakeTimezone do
  def timezone({51.5074, -0.1278}, _),
    do:
      {:ok,
       %{
         "dstOffset" => 3600,
         "rawOffset" => 0,
         "status" => "OK",
         "timeZoneId" => "Europe/London",
         "timeZoneName" => "British Summer Time"
       }}

  def timezone(_coordinates, _),
    do:
      {:ok,
       %{
         "dstOffset" => 3600,
         "rawOffset" => -18_000,
         "status" => "OK",
         "timeZoneId" => "America/New_York",
         "timeZoneName" => "Eastern Daylight Time"
       }}
end
