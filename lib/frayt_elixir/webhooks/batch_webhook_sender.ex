defmodule FraytElixir.Webhooks.BatchWebhookSender do
  use GenServer
  alias Phoenix.PubSub
  alias FraytElixir.Repo

  alias FraytElixir.Shipment.DeliveryBatch

  alias FraytElixir.Accounts.{Company, Location, Shipper}
  alias FraytElixir.Webhooks
  alias FraytElixir.Webhooks.WebhookSupervisor

  import Ecto.Query

  def init_webhook_senders do
    all_pending_webhooks = Webhooks.fetch_unprocessed(:batch)

    delivery_batch_ids = Enum.map(all_pending_webhooks, & &1.record_id)

    delivery_batches =
      from(m in DeliveryBatch,
        where: m.state in [:pending] or m.id in ^delivery_batch_ids
      )
      |> Repo.all()

    Enum.map(delivery_batches, fn delivery_batch ->
      pending_webhooks = Enum.filter(all_pending_webhooks, &(&1.record_id == delivery_batch.id))

      WebhookSupervisor.start_batch_webhook_sender(delivery_batch, pending_webhooks)
    end)
  end

  def start_link(http_post, delivery_batch, pending_webhooks) do
    GenServer.start_link(__MODULE__, [http_post, delivery_batch, pending_webhooks],
      name: name_for(delivery_batch.id)
    )
  end

  def name_for(delivery_batch_id), do: {:global, "batch_webhook_sender:#{delivery_batch_id}"}

  @impl true
  def init([http_post, delivery_batch, pending_webhooks]) do
    :ok = PubSub.subscribe(FraytElixir.PubSub, "batch_state_transitions:#{delivery_batch.id}")

    {:ok,
     %{
       http_post: http_post,
       delivery_batch: delivery_batch,
       pending_webhooks: pending_webhooks
     }, {:continue, :process_pending_webhooks}}
  end

  @impl true
  def handle_continue(:process_pending_webhooks, state) do
    Enum.each(state.pending_webhooks, &Webhooks.process_webhook(&1, state.http_post))

    state = %{state | pending_webhooks: []}
    maybe_shutdown(state)
  end

  @impl true
  def handle_info({record, transition}, %{http_post: http_post} = state) do
    record = Map.put(record, :state_transitions, [transition])

    with %_{shipper: %Shipper{location: %Location{company: %Company{} = company}}} = record <-
           preload_record(record) do
      Webhooks.init_webhook_request(company, record, "batch", http_post, transition)
    end

    maybe_shutdown(state)
  end

  defp preload_record(%DeliveryBatch{} = batch),
    do: Repo.preload(batch, shipper: [location: :company])

  defp maybe_shutdown(state) do
    if state.delivery_batch.state in [:routing_complete, :error] do
      :ok =
        PubSub.unsubscribe(
          FraytElixir.PubSub,
          "batch_state_transitions:#{state.delivery_batch.id}"
        )

      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end
end
