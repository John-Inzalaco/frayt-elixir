defmodule FraytElixir.Repo.Migrations.ChangeMatchNotesToText do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      modify :admin_notes, :text
      modify :delivery_notes, :text
      modify :pickup_notes, :text
    end
  end
end
