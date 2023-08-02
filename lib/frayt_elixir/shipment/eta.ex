defmodule FraytElixir.Shipment.ETA do
  use FraytElixir.Schema
  import Ecto.Changeset
  alias FraytElixir.Shipment.{Match, MatchStop}

  schema "etas" do
    field :arrive_at, :utc_datetime

    belongs_to :match, Match, on_replace: :nilify
    belongs_to :stop, MatchStop, on_replace: :nilify

    timestamps()
  end

  @required ~w(arrive_at)a
  @optional ~w(match_id stop_id)a

  @doc false
  def changeset(eta, attrs) do
    eta
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:etas_match_id_unique, message: "Duplicated match")
    |> unique_constraint(:etas_stop_id_unique, message: "Duplicated match stop")
  end
end
