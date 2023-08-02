defmodule FraytElixir.Screenings.Turn do
  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def request(method, route, payload \\ %{}, opts \\ []) do
    caller = get_config(:api_caller, &FraytElixir.Screenings.Turn.call_api/4)

    caller.(method, route, payload, opts)
  end

  def call_api(method, route, payload, opts) do
    request_url = get_config(:base_url) <> route

    case send_request(method, request_url, payload, opts) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        extract_response(status_code, body)

      {:error, error} ->
        {:error, error}
    end
  end

  defp extract_response(status_code, body) when status_code < 300, do: {:ok, Jason.decode!(body)}

  defp extract_response(status_code, body) do
    error =
      case Jason.decode(body) do
        {:ok, b} -> b
        _ -> body
      end

    {:error, status_code, error}
  end

  defp send_request(:get, url, _payload, opts),
    do: HTTPoison.get(url, build_headers(opts), recv_timout: 15_000)

  defp send_request(method, url, payload, opts),
    do:
      apply(HTTPoison, method, [
        url,
        Jason.encode!(payload),
        build_headers(opts),
        [recv_timout: 15_000]
      ])

  defp build_headers(opts),
    do: [
      {"Content-type", Keyword.get(opts, :content_type, "application/json")},
      {"Authorization", "Bearer #{get_config(:api_key)}"}
    ]

  def search_async(params) do
    params =
      Map.merge(
        %{
          package_id: get_config(:screening_package)
        },
        params
      )

    request(:post, "person/search_async", params, [])
  end

  def get_worker_status(worker_id) do
    request(:get, "person/#{worker_id}/status", %{}, [])
  end
end
