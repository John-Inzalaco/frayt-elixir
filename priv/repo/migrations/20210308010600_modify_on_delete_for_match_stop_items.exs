defmodule FraytElixir.Repo.Migrations.ModifyOnDeleteForMatchStopItems do
  use Ecto.Migration

  def up do
    drop constraint(:match_stop_items, "match_stop_items_match_stop_id_fkey")

    alter table(:match_stop_items) do
      modify(:match_stop_id, references(:match_stops, on_delete: :delete_all, type: :binary_id))
    end
  end

  def down do
    drop constraint(:match_stop_items, "match_stop_items_match_stop_id_fkey")

    alter table(:match_stop_items) do
      modify(:match_stop_id, references(:match_stops, on_delete: :delete_all, type: :binary_id))
    end
  end
end
