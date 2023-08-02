defmodule FraytElixir.Shipment.DeliveryBatchSupervisor do
  use DynamicSupervisor

  alias FraytElixir.Shipment.{DeliveryBatch, DeliveryBatchRouter}

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_routing(%DeliveryBatch{} = delivery_batch) do
    Task.Supervisor.start_child(
      __MODULE__,
      DeliveryBatchRouter,
      :new,
      [
        %{
          delivery_batch: delivery_batch
        }
      ],
      restart: :transient
    )
  end
end
