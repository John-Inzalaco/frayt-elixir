defmodule FraytElixir.Shipment.BatchStateTransition do
  use FraytElixir.Schema

  alias FraytElixir.Shipment.{DeliveryBatch, BatchState}

  schema "batch_state_transitions" do
    field :from, BatchState.Type
    field :to, BatchState.Type
    field :notes, :string
    belongs_to :batch, DeliveryBatch

    timestamps()
  end

  @allowed_fields ~w(from to notes batch_id)a
  @doc false
  def changeset(batch_state_transition, attrs) do
    batch_state_transition
    |> cast(attrs, @allowed_fields)
    |> validate_required([:to, :from, :batch_id])
  end
end
