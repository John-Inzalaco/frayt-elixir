defmodule FraytElixir.ExHubspot do
  require Logger
  alias FraytElixir.Webhooks
  alias FraytElixir.Hubspot

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def request(method, route, payload \\ %{}, opts \\ []) do
    caller = get_config(:api_caller, &FraytElixir.ExHubspot.call_api/4)

    caller.(method, route, payload, opts)
  end

  def create_tokens(code),
    do:
      request(
        :post,
        "/oauth/v1/token",
        %{
          code: code,
          grant_type: "authorization_code",
          redirect_uri: get_config(:account_redirect_uri),
          client_id: get_config(:client_id),
          client_secret: get_config(:client_secret)
        },
        content_type: "application/x-www-form-urlencoded",
        private: true
      )

  def refresh_tokens(refresh_token),
    do:
      request(
        :post,
        "/oauth/v1/token",
        %{
          refresh_token: refresh_token,
          grant_type: "refresh_token",
          redirect_uri: get_config(:account_redirect_uri),
          client_id: get_config(:client_id),
          client_secret: get_config(:client_secret)
        },
        content_type: "application/x-www-form-urlencoded",
        private: true
      )

  def get_refresh_token_data(refresh_token),
    do:
      request(
        :get,
        "/oauth/v1/refresh-tokens/#{refresh_token}",
        %{},
        content_type: "application/x-www-form-urlencoded",
        private: true
      )

  def create_company(attrs),
    do: request(:post, "/crm/v3/objects/companies", %{properties: attrs}, auth: true)

  def create_contact(attrs),
    do: request(:post, "/crm/v3/objects/contacts", %{properties: attrs}, auth: true)

  def update_contact(contact_id, attrs),
    do:
      request(:patch, "/crm/v3/objects/contacts/#{contact_id}", %{properties: attrs}, auth: true)

  def get_contact(contact_id, opts \\ []),
    do:
      request(:get, "/crm/v3/objects/contacts/#{contact_id}#{build_query_params(opts)}", %{},
        auth: true
      )

  def get_company(company_id, opts \\ []),
    do:
      request(
        :get,
        "/crm/v3/objects/companies/#{company_id}#{build_query_params(opts)}",
        %{},
        auth: true
      )

  def get_owner(owner_id),
    do: request(:get, "/crm/v3/owners/#{owner_id}", %{}, auth: true)

  def find_contact(filters, limit \\ 1, pointer \\ 0),
    do:
      request(
        :post,
        "/crm/v3/objects/contacts/search",
        %{filterGroups: build_filters(filters), limit: limit, after: pointer},
        auth: true
      )

  def add_contact_to_company(company_id, contact_id),
    do:
      request(
        :put,
        "/crm/v3/objects/companies/#{company_id}/associations/contacts/#{contact_id}/company_to_contact",
        %{},
        auth: true
      )

  def call_api(method, route, payload, opts) do
    request_id = Webhooks.generate_webhook_id()
    request_url = get_config(:api_url) <> route

    if !opts[:private] do
      Logger.notice(fn -> "Request: #{route} #{inspect(payload)}" end,
        webhook: request_url,
        webhook_id: request_id
      )
    end

    method
    |> send_request(request_url, payload, request_id, opts)
    |> handle_response(request_id, opts)
  end

  defp send_request(:get, url, _payload, request_id, opts),
    do: HTTPoison.get(url, build_headers(request_id, opts))

  defp send_request(method, url, payload, request_id, opts),
    do:
      apply(HTTPoison, method, [
        url,
        build_body(payload, request_id, opts),
        build_headers(request_id, opts)
      ])

  defp build_headers(request_id, opts) do
    headers = [{"Content-type", Keyword.get(opts, :content_type, "application/json")}]

    case opts[:auth] do
      true -> headers ++ build_auth_header(request_id)
      _ -> headers
    end
  end

  defp build_auth_header(request_id) do
    case Hubspot.get_default_account() |> Hubspot.get_access_token() do
      {:ok, access_token} ->
        [{"authorization", "Bearer #{access_token}"}]

      error ->
        Logger.notice(
          fn -> "Request error: Error building auth header: #{inspect(error)}" end,
          webhook_id: request_id
        )

        []
    end
  end

  defp build_body(payload, request_id, opts) do
    payload = payload |> Map.put(:request_id, request_id)

    case Keyword.get(opts, :content_type, "application/json") do
      "application/json" -> Jason.encode!(payload)
      "application/x-www-form-urlencoded" -> URI.encode_query(payload)
    end
  end

  defp build_filters(filters) do
    [
      %{
        filters:
          Enum.map(filters, fn {key, operator, value} ->
            %{
              "propertyName" => key,
              "operator" => operator |> Atom.to_string() |> String.upcase(),
              "value" => value
            }
          end)
      }
    ]
  end

  defp build_query_params(opts) do
    opts
    |> Keyword.take([:properties, :associations])
    |> Enum.map_join("&", fn {key, value} ->
      Atom.to_string(key) <> "=" <> build_query_param(value)
    end)
    |> case do
      "" -> ""
      query -> "?#{query}"
    end
  end

  defp build_query_param(value) when is_list(value),
    do: Enum.join(value, ",")

  defp handle_response(
         {:ok, %HTTPoison.Response{status_code: status_code, body: body}},
         request_id,
         opts
       )
       when status_code < 300 do
    if !opts[:private] do
      Logger.notice(fn -> "Response: Received #{status_code} with #{inspect(body)}" end,
        webhook_id: request_id
      )
    end

    case Jason.decode(body) do
      {:ok, b} -> {:ok, b}
      _ -> handle_response({:error, "Failed to parse JSON: " <> body}, request_id, opts)
    end
  end

  defp handle_response(
         {:ok, %HTTPoison.Response{status_code: status_code, body: body}},
         request_id,
         _opts
       ) do
    Logger.notice(fn -> "Response: Received #{status_code} with #{inspect(body)}" end,
      webhook_id: request_id
    )

    error =
      case Jason.decode(body) do
        {:ok, b} -> b
        _ -> body
      end

    {:error, status_code, error}
  end

  defp handle_response({:error, error}, request_id, _opts) do
    Logger.error(fn -> "Response: Error! #{inspect(error)}" end,
      webhook_id: request_id
    )

    {:error, error}
  end
end
