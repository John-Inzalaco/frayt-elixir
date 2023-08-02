defmodule FraytElixir.Webhooks.WebhookSupervisor do
  use DynamicSupervisor
  alias FraytElixir.Webhooks.MatchWebhookSender
  alias FraytElixir.Webhooks.BatchWebhookSender

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(http_post \\ &HTTPoison.post/4) do
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [http_post])
  end

  def start_match_webhook_sender(match, pending_webhooks \\ nil) do
    child_spec = %{
      id: MatchWebhookSender,
      start: {MatchWebhookSender, :start_link, [match, pending_webhooks]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        send(pid, {match, nil})
    end
  end

  def start_batch_webhook_sender(batch_delivery, pending_webhooks \\ []) do
    child_spec = %{
      id: BatchWebhookSender,
      start: {BatchWebhookSender, :start_link, [batch_delivery, pending_webhooks]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def start_children do
    BatchWebhookSender.init_webhook_senders()
    MatchWebhookSender.init_webhook_senders()
  end
end
