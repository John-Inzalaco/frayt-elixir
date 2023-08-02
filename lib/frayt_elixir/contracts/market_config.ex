defmodule FraytElixir.Contracts.MarketConfig do
  use FraytElixir.Schema
  alias FraytElixir.Contracts.Contract
  alias FraytElixir.Markets.Market

  schema "contract_market_configs" do
    field :multiplier, :float

    belongs_to :contract, Contract, primary_key: true
    belongs_to :market, Market, primary_key: true
  end

  def changeset(multiplier, attrs) do
    multiplier
    |> cast(attrs, [:contract_id, :market_id, :multiplier])
    |> unique_constraint([:contract_id, :market_id])
    |> validate_required(:multiplier)
  end
end
