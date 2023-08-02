defmodule FraytElixir.Repo.Migrations.Dem410AddSignatureFieldsToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :signature_type, :string, default: "electronic"
      add :signature_instructions, :text
    end
  end
end
