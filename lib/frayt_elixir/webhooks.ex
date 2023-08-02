defmodule FraytElixir.Webhooks do
  import Ecto.Query
  use FraytElixir.Schema

  alias FraytElixir.Repo
  alias FraytElixir.Webhooks.WebhookRequest
  alias FraytElixir.Integrations.Bringg
  alias FraytElixir.Integrations.Walmart
  alias FraytElixir.Integrations.Default
  alias FraytElixir.Accounts.Company

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def generate_webhook_id do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()}, 16_777_216)::24,
      :erlang.unique_integer()::32
    >>

    Base.url_encode64(binary)
  end

  def send_webhook(webhook_request, http_post) do
    if webhook_request.company.webhook_url || integration_available?(webhook_request.company) do
      body = Map.put(webhook_request.payload, "payload_id", webhook_request.id)

      webhook_url =
        if integration_available?(webhook_request.company) do
          webhook_request.webhook_url
        else
          webhook_request.company.webhook_url
        end

      case http_post.(
             webhook_url,
             Jason.encode!(body),
             build_headers(webhook_request.company),
             [recv_timeout: 15_000] ++ build_proxy()
           ) do
        {:ok, _resp} = res ->
          {:ok, res}

        {:error, code} ->
          {:error, code}
      end
    else
      {:error, :invalid_settings}
    end
  end

  defp build_proxy do
    socks_host = get_config(:socks_host)

    if socks_host do
      [
        proxy: {:socks5, String.to_charlist(socks_host), 8040},
        socks5_user: get_config(:socks_user),
        socks5_pass: get_config(:socks_pass)
      ]
    else
      []
    end
  end

  defp build_headers(company) do
    config = company.webhook_config
    webhook_processor = get_webhook_processor(company)

    [{"Content-Type", "application/json"}]
    |> webhook_processor.put_auth_header(config)
  end

  def fetch_unprocessed(webhook_type) do
    min_date = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60 * 1000)

    WebhookRequest
    |> where(
      [w],
      w.state == "pending" and w.webhook_type == ^webhook_type and w.updated_at >= ^min_date
    )
    |> preload([:company])
    |> Repo.all()
  end

  def create_webhook_request(company, attrs) do
    %WebhookRequest{}
    |> WebhookRequest.changeset(attrs)
    |> put_assoc(:company, company)
    |> Repo.insert()
  end

  def update_webhook_request(request, args) do
    request
    |> WebhookRequest.changeset(args)
    |> Repo.update()
  end

  def init_webhook_request(company, record, type, http_post, transition) do
    if company.webhook_url || integration_available?(company) do
      get_webhook_processor(company).build_webhook_request(company, record, transition)
      |> Enum.map(fn {webhook_url, body} ->
        {:ok, request} =
          create_webhook_request(company, %{
            webhook_url: webhook_url,
            payload: body,
            webhook_type: type,
            state: "pending",
            record_id: record.id,
            company_id: company.id,
            sent_at: DateTime.utc_now()
          })

        process_webhook(request, http_post)
      end)
    else
      {:ok, nil}
    end
  end

  def process_pending_webhooks(type, http_post) do
    fetch_unprocessed(type)
    |> Repo.preload(:company)
    |> Enum.each(&process_webhook(&1, http_post))
  end

  def process_webhook(request, http_post) do
    case send_webhook(request, http_post) do
      {:ok, {:ok, %HTTPoison.Response{body: body, status_code: status_code}}} ->
        update_webhook_request(request, %{
          response: inspect(%{body: body, status_code: status_code}),
          state: :completed
        })

      {:error, msg} ->
        update_webhook_request(request, %{response: inspect(msg), state: :failed})
    end
  end

  def get_webhook_processor(%Company{integration: integration}) do
    case integration do
      :bringg ->
        Bringg

      :walmart ->
        Walmart

      _ ->
        Default
    end
  end

  defp integration_available?(company) do
    is_nil(company.webhook_url) && not is_nil(company.integration)
  end
end
