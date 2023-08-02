defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM193AddingSignatureRequiredField" do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :signature_required, :boolean, default: true
    end

    alter table(:companies) do
      add :signature_required, :boolean, default: true
    end
  end
end
