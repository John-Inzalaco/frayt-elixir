defmodule FraytElixir.Test.TomTom.FakeWaypointOptimization do
  def post(url, payload, opts),
    do: handle_request(:post, URI.parse(url), Jason.decode!(payload), opts)

  def handle_request(
        :post,
        %URI{path: "/routing/waypointoptimization/1/best/" = path},
        payload,
        opts
      ),
      do:
        {:ok,
         payload
         |> build_route()
         |> Jason.encode!()
         |> build_response(
           200,
           path,
           payload,
           opts
         )}

  defp build_route(%{"waypoints" => waypoints}) do
    waypoints =
      waypoints
      |> Enum.with_index()
      |> Enum.sort_by(fn {%{"point" => %{"latitude" => lat, "longitude" => lng}}, index} ->
        if index > 0 do
          {lat, lng}
        else
          index
        end
      end)

    {_, first_index} = List.first(waypoints)
    {_, last_index} = List.last(waypoints)

    leg_summaries =
      waypoints
      |> Enum.map(fn {_value, index} ->
        %{
          "destinationIndex" => index,
          "lengthInMeters" => 2000,
          "originIndex" => 0,
          "travelTimeInSeconds" => 10 * 60
        }
      end)

    route_summary = %{
      "destinationIndex" => last_index,
      "lengthInMeters" => 2000 * length(waypoints),
      "originIndex" => first_index,
      "travelTimeInSeconds" => 10 * 60 * length(waypoints)
    }

    optimized_order = Enum.map(waypoints, fn {_, index} -> index end)

    %{
      "optimizedOrder" => optimized_order,
      "summary" => %{
        "legSummaries" => leg_summaries,
        "routeSummary" => route_summary
      }
    }
  end

  defp build_response(response, code, path, payload, opts),
    do: %HTTPoison.Response{
      body: response,
      headers: [],
      request: %HTTPoison.Request{
        body: payload,
        headers: [],
        method: :post,
        options: opts,
        params: %{},
        url: path
      },
      request_url: path,
      status_code: code
    }
end
