defmodule FraytElixir.Shipment.MatchStop do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema

  alias FraytElixir.Shipment.{
    Match,
    Address,
    MatchStopItem,
    MatchStopStateTransition,
    DeliveryBatch,
    Contact,
    MatchStopState,
    MatchStopSignatureType,
    ETA
  }

  alias FraytElixir.Photo

  @forbidden_update_fields [:has_load_fee, :needs_pallet_jack]

  schema "match_stops" do
    field :state, MatchStopState.Type, default: :pending
    field :dropoff_by, :utc_datetime
    field :identifier, :string
    field :distance, :float
    field :radial_distance, :float
    # Should be :load_required. Load fee requires this to be true, and ` to be over 250lbs
    field :has_load_fee, :boolean, default: false
    field :needs_pallet_jack, :boolean, default: false
    field :tip_price, :integer, default: 0
    field :self_recipient, :boolean, default: true
    field :index, :integer, default: 0
    field :signature_name, :string
    field :signature_photo, Photo.Type
    field :destination_photo, Photo.Type
    field :delivery_notes, :string
    field :destination_photo_required, :boolean
    field :signature_required, :boolean, default: true
    field :signature_type, MatchStopSignatureType.Type, default: :electronic
    field :signature_instructions, :string
    field :po, :string

    belongs_to :destination_address, Address, on_replace: :nilify
    belongs_to :recipient, Contact, on_replace: :update
    belongs_to :match, Match
    belongs_to :delivery_batch, DeliveryBatch

    has_many :items, MatchStopItem, on_replace: :delete
    has_many :state_transitions, MatchStopStateTransition

    has_one :eta, ETA, foreign_key: :stop_id

    # deprecated
    field :base_price, :integer
    field :driver_cut, :float, default: 0.75

    timestamps()
  end

  @allowed_fields ~w(
    state identifier self_recipient tip_price has_load_fee
    needs_pallet_jack index delivery_notes destination_photo_required
    dropoff_by signature_required recipient_id po signature_type
    signature_instructions signature_name
  )a

  @required_fields ~w(
    state index tip_price has_load_fee self_recipient signature_type
  )a

  @doc false
  def changeset(match_stop, attrs) do
    match_stop
    |> cast(attrs, @allowed_fields)
    |> cast_assoc(:items)
    |> assoc_when(:recipient, [{:self_recipient, :equal_to, false}], required: true)
    |> Address.assoc_address(match_stop, :destination_address)
    |> validate_stop()
    |> validate_number(:tip_price, greater_than_or_equal_to: 0)
  end

  def delivery_batch_changeset(match_stop, attrs) do
    match_stop
    |> changeset(attrs)
    |> validate_required([:destination_photo_required])
    |> validate_assoc_length(:items, min: 1)
  end

  def metrics_changeset(match_stop, attrs) do
    match_stop
    |> cast(attrs, [:distance, :radial_distance, :index])
    |> validate_metrics()
  end

  def validation_changeset(match_stop, attrs, match) do
    changeset = cast(match_stop, attrs, [])

    item_cs = {MatchStopItem, :validation_changeset, [match, apply_changes(changeset)]}

    changeset
    |> cast_assoc(:items, with: item_cs)
    |> validate_assoc_length(:items, min: 1)
    |> validate_stop()
    |> validate_metrics()
    |> validate_required([:destination_photo_required, :destination_address_id])
    |> validate_services(match)
  end

  def override_changeset(match_stop, attrs, match) do
    match_stop
    |> cast(attrs, [:needs_pallet_jack])
    |> validate_required([:needs_pallet_jack])
    |> validate_services(match)
  end

  def photo_changeset(match_stop, attrs) do
    match_stop
    |> cast(attrs, [:signature_name])
    |> cast_attachments(attrs, [:signature_photo])
    |> cast_attachments(attrs, [:destination_photo])
  end

  def price_changeset(match_stop, attrs) do
    match_stop
    |> cast(attrs, [:tip_price, :base_price, :driver_cut])
    |> validate_number(:tip_price, greater_than_or_equal_to: 0)
    |> validate_number(:base_price, greater_than_or_equal_to: 0)
    |> validate_number(:driver_cut, greater_than_or_equal_to: 0)
    |> validate_required([:tip_price, :base_price, :driver_cut])
  end

  def state_changeset(match_stop, attrs) do
    match_stop
    |> cast(attrs, [:state])
    |> validate_required([:state])
  end

  def dropoff_changeset(match_stop, attrs) do
    match_stop
    |> state_changeset(attrs)
    |> validate_inclusion(:state, [:delivered, :undeliverable])
  end

  def api_update_changeset(match, attrs) do
    match
    |> cast(attrs, @forbidden_update_fields)
    |> valid_fields()
  end

  defp validate_metrics(changeset) do
    changeset
    |> validate_required([:distance, :radial_distance])
    |> validate_number(:distance, greater_than_or_equal_to: 0)
    |> validate_number(:radial_distance, greater_than_or_equal_to: 0)
  end

  defp validate_stop(changeset) do
    changeset
    |> validate_required(@required_fields)
    |> validate_required_when(
      :signature_instructions,
      [{:signature_type, :equal_to, :photo}],
      message: "can't be blank for signature type"
    )
    |> validate_length(:delivery_notes, max: 512)
    |> unique_constraint(:match_id)
    |> unique_constraint(:match_id_index)
  end

  defp validate_services(changeset, match),
    do:
      changeset
      |> validate_pallet_jack(match)
      |> validate_load_unload()

  defp validate_load_unload(changeset) do
    needs_load = get_field(changeset, :has_load_fee)

    has_items =
      changeset
      |> get_field(:items)
      |> Enum.any?(&(&1.type == :item))

    if needs_load and not has_items do
      add_error(changeset, :has_load_fee, "is only available for items",
        validation: :valid_load_unload
      )
    else
      changeset
    end
  end

  defp validate_pallet_jack(changeset, match) do
    needs_pallet_jack = get_field(changeset, :needs_pallet_jack)

    has_pallets =
      changeset
      |> get_field(:items)
      |> Enum.any?(&(&1.type == :pallet))

    cond do
      needs_pallet_jack and match.vehicle_class < 4 ->
        add_error(changeset, :needs_pallet_jack, "is only available for box trucks",
          validation: :valid_pallet_jack
        )

      needs_pallet_jack and not has_pallets ->
        add_error(changeset, :needs_pallet_jack, "is only available for pallets",
          validation: :valid_pallet_jack
        )

      not needs_pallet_jack and has_pallets and match.unload_method == :lift_gate ->
        add_error(
          changeset,
          :needs_pallet_jack,
          "is required when the unload method is a lift gate",
          validation: :valid_pallet_jack
        )

      true ->
        changeset
    end
  end

  defp valid_fields(changeset) do
    @forbidden_update_fields
    |> Enum.reduce(changeset, fn field, acc ->
      if get_change(acc, field) != nil,
        do: add_error(acc, field, "cannot be updated", validation: :uneditable_field),
        else: acc
    end)
  end
end
