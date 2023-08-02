defmodule FraytElixir.Repo.Migrations.ConvertDeliveryNotesToText do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      modify :delivery_notes, :text
    end
  end
end
