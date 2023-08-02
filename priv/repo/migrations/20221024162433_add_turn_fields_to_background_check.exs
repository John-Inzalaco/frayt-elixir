defmodule FraytElixir.Repo.Migrations.AddTurnFieldsToBackgroundCheck do
  use Ecto.Migration

  def change do
    alter table(:background_checks) do
      add :turn_id, :string
      add :turn_url, :string
    end
  end
end
