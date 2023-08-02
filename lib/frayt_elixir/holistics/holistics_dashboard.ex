defmodule FraytElixir.Holistics.HolisticsDashboard do
  use FraytElixir.Schema
  import Ecto.Changeset

  schema "holistics_dashboards" do
    field :name, :string
    field :description, :string
    field :embed_code, :string
    field :secret_key, :string

    timestamps()
  end

  @doc false
  def changeset(holistics_dashboard, attrs) do
    holistics_dashboard
    |> cast(attrs, [:secret_key, :embed_code, :name, :description])
    |> validate_required([:secret_key, :embed_code, :name])
  end
end
