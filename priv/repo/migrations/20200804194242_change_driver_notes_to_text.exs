defmodule FraytElixir.Repo.Migrations.ChangeDriverNotesToText do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      modify :notes, :text
    end
  end
end
