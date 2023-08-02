defmodule FraytElixir.Shipment.DeliveryBatch do
  use FraytElixir.Schema
  import Ecto.Query, only: [from: 2]

  alias FraytElixir.Accounts.{Location, Shipper}
  alias FraytElixir.Shipment.{Address, BatchState, Match, MatchStop, BatchStateTransition}
  alias FraytElixir.CustomContracts
  alias Ecto.Changeset

  schema "delivery_batches" do
    field :pickup_at, :utc_datetime
    field :complete_by, :utc_datetime
    field :state, BatchState.Type, default: :pending
    field :routific_job_id, :string
    field :po, :string
    field :contract, :string
    field :pickup_notes, :string
    field :service_level, :integer

    belongs_to :location, Location
    belongs_to :shipper, Shipper
    belongs_to :address, Address, on_replace: :nilify
    has_many :match_stops, MatchStop
    has_many :matches, Match
    has_many :state_transitions, BatchStateTransition, foreign_key: :batch_id

    timestamps()
  end

  def filter_by_state(query, nil), do: query
  def filter_by_state(query, state), do: from(b in query, where: b.state == ^state)

  def filter_by_query(query, nil), do: query

  def filter_by_query(query, value),
    do:
      from(b in query,
        left_join: s in assoc(b, :shipper),
        left_join: a in assoc(b, :address),
        where:
          ilike(b.po, ^"%#{value}%") or ilike(b.contract, ^"%#{value}%") or
            ilike(fragment("?::text", b.id), ^"%#{value}%") or
            ilike(b.routific_job_id, ^"%#{value}%") or
            ilike(fragment("CONCAT(?, ' ', ?)", s.first_name, s.last_name), ^"%#{value}%") or
            ilike(fragment("CONCAT(?, ', ', ?)", a.city, a.state), ^"%#{value}%")
      )

  @doc false

  def changeset(delivery_batch, attrs) do
    delivery_batch
    |> cast(attrs, [
      :contract,
      :pickup_at,
      :complete_by,
      :pickup_notes,
      :location_id,
      :state,
      :routific_job_id,
      :shipper_id,
      :address_id,
      :service_level,
      :po
    ])
    |> cast_assoc(:match_stops, with: &MatchStop.delivery_batch_changeset/2)
    |> Address.assoc_address(delivery_batch, :address)
    |> validate_required([:service_level, :pickup_at])
    |> validate_length(:match_stops, min: 2)
    |> validate_state_transition()
    |> validate_inclusion(:contract, CustomContracts.get_contracts())
  end

  defp validate_state_transition(
         %Changeset{data: %{state: :canceled}, changes: %{state: state}} = changeset
       )
       when is_bitstring(state) do
    state = state |> String.to_atom()
    validate_state_transition(changeset, state)
  end

  defp validate_state_transition(
         %Changeset{data: %{state: :canceled}, changes: %{state: state}} = changeset
       ),
       do: validate_state_transition(changeset, state)

  defp validate_state_transition(changeset), do: changeset

  defp validate_state_transition(
         %Changeset{data: %{state: :canceled}} = changeset,
         state
       )
       when state != :canceled,
       do: add_error(changeset, :state, "transitioning to unallowed state", validation: :state)

  defp validate_state_transition(
         %Changeset{data: %{state: :canceled}} = changeset,
         _state
       ),
       do: changeset
end
