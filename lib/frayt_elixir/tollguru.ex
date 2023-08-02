defmodule FraytElixir.TollGuru do
  require Logger
  alias FraytElixir.Webhooks

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def calculate_toll(attrs) do
    request(:post, "/here", attrs)
  end

  def request(method, route, payload \\ %{}) do
    caller = get_config(:api_caller, &FraytElixir.TollGuru.call_api/3)

    caller.(method, route, payload)
  end

  def call_api(method, route, payload \\ %{}) do
    request_id = Webhooks.generate_webhook_id()
    request_url = get_config(:api_url) <> route

    headers = [{"x-api-key", get_config(:api_key)}, {"Content-type", "application/json"}]

    Logger.info(fn -> "Request: #{inspect(payload)}" end,
      webhook: request_url,
      webhook_id: request_id
    )

    method
    |> case do
      :post -> post(request_url, payload, headers)
    end
    |> handle_response(request_id)
  end

  def post(url, properties, headers) do
    body = Jason.encode!(properties)

    HTTPoison.post(url, body, headers, recv_timeout: 10_000)
  end

  def handle_response(
        {:ok, %HTTPoison.Response{status_code: status_code, body: body}},
        request_id
      )
      when status_code < 300 do
    Logger.info(fn -> "Response: Received #{status_code} with #{inspect(body)}" end,
      webhook_id: request_id
    )

    {:ok, Jason.decode!(body)}
  end

  def handle_response(
        {:ok, %HTTPoison.Response{status_code: status_code, body: body}},
        request_id
      ) do
    Logger.info(fn -> "Response: Received #{status_code} with #{inspect(body)}" end,
      webhook_id: request_id
    )

    error =
      case Jason.decode(body) do
        {:ok, b} -> b
        _ -> body
      end

    {:error, status_code, error}
  end

  def handle_response({:error, error}, request_id) do
    Logger.error(fn -> "Response: Error! #{inspect(error)}" end,
      webhook_id: request_id
    )

    {:error, error}
  end
end
