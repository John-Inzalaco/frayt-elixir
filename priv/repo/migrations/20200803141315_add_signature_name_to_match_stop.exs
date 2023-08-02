defmodule FraytElixir.Repo.Migrations.AddSignatureNameToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :signature_name, :string
    end
  end
end
