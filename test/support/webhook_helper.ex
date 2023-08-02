defmodule FraytElixir.Test.WebhookHelper do
  use ExUnit.CaseTemplate
  alias FraytElixir.Webhooks.WebhookSupervisor

  def webhook_post(url, body, headers, options) do
    {:ok,
     %HTTPoison.Response{
       body: Jason.decode!(body),
       headers: headers,
       request: %HTTPoison.Request{
         body: body,
         headers: [],
         method: :post,
         options: options,
         params: %{},
         url: url
       },
       request_url: url,
       status_code: 201
     }}
  end

  def failing_webhook_post(_url, _body, _headers, _options) do
    {:error, %HTTPoison.Error{reason: "something went wrong"}}
  end

  def listen_webhook_post(pid) do
    fn url, body, headers, options ->
      send(pid, webhook_post(url, body, headers, options))
    end
  end

  def listen_failing_webhook_post(pid) do
    fn url, body, headers, options ->
      send(pid, failing_webhook_post(url, body, headers, options))
    end
  end

  def start_match_webhook_sender(pid) do
    pid = start_supervised!({WebhookSupervisor, listen_webhook_post(pid)})

    %{pid: pid}
  end

  def start_failing_match_webhook_sender(pid) do
    pid = start_supervised!({WebhookSupervisor, listen_failing_webhook_post(pid)})

    %{pid: pid}
  end

  def start_batch_webhook_sender(pid) do
    pid = start_supervised!({WebhookSupervisor, listen_webhook_post(pid)})

    %{pid: pid}
  end

  def start_batch_webhook_sender_with_failing_webhook(pid) do
    pid = start_supervised!({WebhookSupervisor, listen_failing_webhook_post(pid)})

    %{pid: pid}
  end
end

# def start_match_webhook_sender(_) do
#   post = fn url, body, headers -> webhook_response(url, body, headers) end
#   {:ok, _pid} = start_supervised({MatchWebhookSender, post})
# end
