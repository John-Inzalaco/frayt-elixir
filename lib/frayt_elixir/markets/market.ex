defmodule FraytElixir.Markets.Market do
  use FraytElixir.Schema
  alias FraytElixir.Markets.MarketZipCode
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Vehicle.VehicleType
  import Ecto.Query, only: [from: 2]
  import FraytElixir.Guards

  schema "markets" do
    field :name, :string
    field :region, :string
    field :markup, :float, default: 1.0
    field :sla_pickup_modifier, :integer, default: 0
    field :has_box_trucks, :boolean, default: false
    field :calculate_tolls, :boolean, default: false
    field :currently_hiring, {:array, VehicleType.Type}, default: []
    has_many :zip_codes, MarketZipCode, on_replace: :delete, on_delete: :delete_all
    has_many :matches, Match, on_delete: :nilify_all

    timestamps()
  end

  def filter_by_hiring(query, nil), do: query

  def filter_by_hiring(query, true),
    do: from(m in query, where: fragment("array_length(?, 1)", m.currently_hiring) > 0)

  def filter_by_hiring(query, false),
    do: from(m in query, where: fragment("array_length(?, 1)", m.currently_hiring) == 0)

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(m in query,
        left_join:
          query in subquery(
            from(z in MarketZipCode,
              where: ilike(z.zip, ^"%#{search_query}%"),
              group_by: z.market_id,
              select: z.market_id
            )
          ),
        on: query.market_id == m.id,
        where: ilike(m.name, ^"%#{search_query}%") or not is_nil(query)
        # group_by: m.id
      )

  @allowed_fields ~w(name region markup sla_pickup_modifier has_box_trucks calculate_tolls currently_hiring)a
  @doc false
  def changeset(market, attrs) do
    market
    |> cast_from_form(attrs, @allowed_fields)
    |> cast_assoc(:zip_codes, with: &MarketZipCode.market_changeset/2)
    |> validate_required([:name, :markup, :sla_pickup_modifier, :has_box_trucks, :calculate_tolls])
    |> validate_number(:markup, greater_than_or_equal_to: 0)
    |> unique_constraint(:name, message: "A Market with this name already exists.")
    |> cast_assoc(:zip_codes, with: &MarketZipCode.market_changeset/2)
    |> validate_assoc_length(:zip_codes, min: 1)
  end
end
