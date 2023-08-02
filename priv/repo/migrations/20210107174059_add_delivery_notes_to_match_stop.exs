defmodule FraytElixir.Repo.Migrations.AddDeliveryNotesToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :delivery_notes, :string
    end
  end
end
