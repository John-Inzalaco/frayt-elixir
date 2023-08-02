defmodule FraytElixir.Webhooks.BatchWebhookSenderTest do
  use FraytElixir.DataCase

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  alias Phoenix.PubSub
  alias FraytElixir.Webhooks.WebhookRequest
  alias FraytElixirWeb.API.V2x1.BatchView
  alias FraytElixir.Webhooks.WebhookSupervisor

  import FraytElixir.Test.WebhookHelper

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    start_batch_webhook_sender(self())
  end

  setup :start_match_supervisor

  describe "batch state updates" do
    test "sends updates" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      %{id: batch_id} =
        batch =
        insert(:delivery_batch,
          state: :routing,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      transition =
        insert(:batch_state_transition,
          from: :pending,
          to: :routing,
          batch: batch
        )

      {:ok, pid} = WebhookSupervisor.start_batch_webhook_sender(batch)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      PubSub.broadcast!(
        FraytElixir.PubSub,
        "batch_state_transitions:#{batch.id}",
        {batch, transition}
      )

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^batch_id,
                          "state" => "routing",
                          "state_transition" => %{
                            "notes" => nil,
                            "from" => "pending",
                            "to" => "routing"
                          }
                        }
                      }}

      assert Repo.all(WebhookRequest) |> Enum.count() == 1
    end

    test "handles errors" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      %{id: batch_id} =
        batch =
        insert(:delivery_batch,
          state: :routing,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      insert(:batch_state_transition,
        from: :pending,
        to: :routing,
        batch: batch
      )

      {:ok, pid} = WebhookSupervisor.start_batch_webhook_sender(batch)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      FraytElixir.Shipment.DeliveryBatches.update_state(batch, :error, "Failure!")

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^batch_id,
                          "state" => "error",
                          "state_transition" => %{
                            "from" => "routing",
                            "to" => "error",
                            "notes" => "Failure!"
                          }
                        }
                      }}
    end
  end

  describe "process webhook requests on startup" do
    test "should process webhook requests of type batch" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      %{id: batch_id} =
        batch =
        insert(:delivery_batch,
          state: :routing_complete,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      insert(:batch_state_transition,
        from: :routing,
        to: :routing_complete,
        batch: batch
      )

      payload = BatchView.render("batch.json", %{batch: batch})

      webhook_request =
        insert(:webhook_request, %{
          webhook_type: "batch",
          payload: payload,
          company: company,
          record_id: batch_id,
          state: "pending"
        })

      FraytElixir.Webhooks.BatchWebhookSender.init_webhook_senders()
      |> Enum.each(fn {:ok, pid} ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      end)

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^batch_id,
                          "state" => "routing_complete",
                          "state_transition" => %{
                            "notes" => nil,
                            "from" => "routing",
                            "to" => "routing_complete"
                          }
                        }
                      }}

      :timer.sleep(1000)
      assert %{state: :completed} = Repo.get(WebhookRequest, webhook_request.id)
    end

    test "should save errors when processing webhook requests of type batch_webhook on startup" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      %{id: batch_id} =
        batch =
        insert(:delivery_batch,
          state: :routing_complete,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      insert(:batch_state_transition,
        from: :routing,
        to: :routing_complete,
        batch: batch
      )

      payload = BatchView.render("batch.json", %{batch: batch})

      webhook_request =
        insert(:webhook_request, %{
          webhook_type: "batch",
          payload: payload,
          company: company,
          record_id: batch_id,
          state: "pending"
        })

      :ok = stop_supervised(WebhookSupervisor)
      start_batch_webhook_sender_with_failing_webhook(self())

      FraytElixir.Webhooks.BatchWebhookSender.init_webhook_senders()
      |> Enum.each(fn {:ok, pid} ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      end)

      assert_receive {:error, _msg}
      :timer.sleep(1000)
      assert %{state: :failed} = Repo.get(WebhookRequest, webhook_request.id)
    end
  end
end
