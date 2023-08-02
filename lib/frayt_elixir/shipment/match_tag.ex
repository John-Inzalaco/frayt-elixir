defmodule FraytElixir.Shipment.MatchTag do
  use FraytElixir.Schema
  alias FraytElixir.Shipment.Match

  schema "match_tags" do
    field :name, MatchTagEnum
    belongs_to :match, Match

    timestamps()
  end

  @doc false
  def changeset(match_tags, attrs) do
    match_tags
    |> cast(attrs, [:name, :match_id])
    |> validate_required([:name, :match_id])
  end
end
