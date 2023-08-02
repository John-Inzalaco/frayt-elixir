defmodule FraytElixir.TomTom.WaypointOptimization do
  alias FraytElixir.TomTom

  def call_api(method, route, payload \\ %{}, opts \\ []) do
    caller = TomTom.get_config(:optimization_api_caller, HTTPoison)

    apply(caller, method, [route, payload, opts])
  end

  def send_request(method, path, payload, opts \\ []) do
    body = payload |> Jason.encode!()
    content_type = {"Content-Type", "application/json"}
    url = tomtom_url(path)

    case call_api(method, url, body, opts ++ [content_type]) do
      {:ok, response} -> process_response(response)
      {:error, error} -> {:error, error}
    end
  end

  def optimize_route(route), do: send_request(:post, "routing/waypointoptimization/1/best", route)

  defp process_response(%HTTPoison.Response{status_code: 200, body: body}),
    do: body |> Jason.decode()

  defp process_response(%HTTPoison.Response{status_code: 400}),
    do: {:error, "Request was invalid"}

  defp process_response(%HTTPoison.Response{status_code: 403}),
    do: {:error, "Invalid API key"}

  defp tomtom_url(path) do
    api_url = TomTom.get_config(:api_url)
    api_key = TomTom.get_config(:api_key)

    "#{api_url}#{path}/?key=#{api_key}"
  end
end
