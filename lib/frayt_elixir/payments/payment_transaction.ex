defmodule FraytElixir.Payments.PaymentTransaction do
  use FraytElixir.Schema
  import FraytElixir.Guards
  import Ecto.Query, only: [from: 2]
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Payments.{TransactionReason, TransactionType, DriverBonus}

  schema "payment_transactions" do
    field :payment_provider_response, :string
    field :status, :string
    field :external_id, :string
    field :transaction_type, TransactionType
    field :transaction_reason, TransactionReason
    field :amount, :integer
    field :canceled_at, :utc_datetime
    field :old_transaction_id, :string
    belongs_to :match, Match
    belongs_to :driver, Driver
    has_one :driver_bonus, DriverBonus
    timestamps()
  end

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(m in query,
        join: match in assoc(m, :match),
        join: shipper in assoc(match, :shipper),
        left_join: driver in assoc(match, :driver),
        left_join: coupon in assoc(match, :coupon),
        where:
          ilike(
            fragment("CONCAT(?, ' ', ?)", shipper.first_name, shipper.last_name),
            ^"%#{search_query}%"
          ),
        or_where:
          ilike(
            fragment("CONCAT(?, ' ', ?)", driver.first_name, driver.last_name),
            ^"%#{search_query}%"
          ),
        or_where: ilike(fragment("CONCAT('#', ?)", match.id), ^"%#{search_query}%"),
        or_where: ilike(fragment("CONCAT('#', ?)", match.shortcode), ^"%#{search_query}%"),
        or_where: ilike(coupon.code, ^"%#{search_query}%"),
        or_where: ilike(m.transaction_type, ^"%#{search_query}%"),
        or_where:
          ilike(
            fragment("CASE WHEN ? IS NOT NULL THEN 'void' ELSE ? END", m.canceled_at, m.status),
            ^"%#{search_query}%"
          ),
        or_where: ilike(m.payment_provider_response, ^"%#{search_query}%")
      )

  def where_match_is(query, match_id),
    do:
      from(p in query,
        where: p.match_id == ^match_id
      )

  @doc false
  def changeset(payment_transaction, attrs) do
    payment_transaction
    |> cast(attrs, [
      :status,
      :external_id,
      :payment_provider_response,
      :match_id,
      :transaction_type,
      :transaction_reason,
      :driver_id,
      :amount,
      :canceled_at
    ])
    |> validate_required([:status, :transaction_reason])
  end
end
