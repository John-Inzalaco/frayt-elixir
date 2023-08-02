defmodule FraytElixir.Repo.Migrations.AddExternalIdToMatchStopItem do
  use Ecto.Migration

  def change do
    alter table(:match_stop_items) do
      add :external_id, :string
    end
  end
end
