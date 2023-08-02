defmodule FraytElixir.Repo.Migrations.AddDriverNotes do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :notes, :string
    end
  end
end
