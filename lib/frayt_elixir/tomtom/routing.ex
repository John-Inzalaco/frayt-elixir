defmodule FraytElixir.TomTom.Routing do
  alias FraytElixir.TomTom

  def calculate_route(url) do
    content_type = {"Content-Type", "application/json"}

    case HTTPoison.get(url, [content_type]) do
      {:ok, response} -> process_response(response)
      {:error, %HTTPoison.Error{reason: :timeout}} -> {:error, "Request took too long"}
    end
  end

  def calculate_route(route, options) do
    default = [key: TomTom.get_config(:api_key), avoid: "ferries"]
    options = Keyword.merge(default, options)

    route
    |> convert_to_colon_delimited_list()
    |> path_url(options)
    |> calculate_route()
  end

  def calculate_batch(routes, options \\ %{})

  def calculate_batch(routes, _) when routes == [], do: {:ok, %{"batchItems" => []}}

  def calculate_batch(routes, options) do
    url =
      "#{TomTom.get_config(:api_url)}routing/1/batch/sync/json?key=#{TomTom.get_config(:api_key)}"

    headers = [{"Content-Type", "application/json"}]

    body =
      %{
        batchItems:
          Enum.map(routes, fn coord_list ->
            %{query: path_url(convert_to_colon_delimited_list(coord_list), options, false)}
          end)
      }
      |> Poison.encode!()

    case HTTPoison.post(url, body, headers, recv_timeout: 60_000) do
      {:ok, response} -> process_response(response)
      {:error, %HTTPoison.Error{reason: :timeout}} -> {:error, "Request took too long"}
    end
  end

  defp process_response(%HTTPoison.Response{status_code: 200, body: body}),
    do: body |> Jason.decode()

  defp process_response(%HTTPoison.Response{status_code: 400, body: _body}),
    do: {:error, "Request was invalid"}

  defp process_response(%HTTPoison.Response{status_code: 403}),
    do: {:error, "Invalid API key"}

  defp convert_to_colon_delimited_list(route) do
    Enum.map_join(route, ":", fn {lat, lng} ->
      "#{lat},#{lng}"
    end)
  end

  defp path_url(coord_list, options, include_api_url \\ true) do
    api_url =
      if include_api_url,
        do: "#{TomTom.get_config(:api_url)}routing/1",
        else: ""

    options
    |> Enum.map(fn {key, value} ->
      "#{key}=#{value}&"
    end)
    |> Enum.reduce(
      "#{api_url}/calculateRoute/#{coord_list}/json?",
      &"#{&2}#{&1}"
    )
    |> String.slice(0..-2)
  end
end
