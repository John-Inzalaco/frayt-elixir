defmodule FraytElixir.Shipment.BatchState do
  @states %{
    pending: %{index: 0, description: "is the default state"},
    routing: %{index: 1, description: "we are finding the most optimal combination of routes"},
    routing_complete: %{
      index: 2,
      description:
        "we have successfully routed your Batch, and created corresponding Matches in our system"
    },
    error: %{
      index: -2,
      description: "there was an error while routing. There is a corresponding error message."
    },
    canceled: %{index: -1, description: "the shipper has canceled the entire batch"}
  }

  use FraytElixir.Type.StateEnum,
    states: @states
end
