defmodule FraytElixir.Markets.MarketZipCode do
  use FraytElixir.Schema
  alias FraytElixir.Markets.Market

  schema "market_zip_codes" do
    field :zip
    belongs_to :market, Market

    timestamps()
  end

  @doc false
  def changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:zip, :market_id])
    |> validate_required([:market_id])
    |> validate_zip()
  end

  def market_changeset(market_zip_code, attrs) do
    market_zip_code
    |> cast(attrs, [:zip])
    |> validate_zip()
  end

  def validate_zip(changeset) do
    changeset
    |> validate_required([:zip])
    |> validate_length(:zip, is: 5)
    |> validate_format(:zip, ~r/^\d+$/, message: "can only contain numbers")
    |> unique_constraint(:zip, message: "Zip code already exists.")
  end
end
