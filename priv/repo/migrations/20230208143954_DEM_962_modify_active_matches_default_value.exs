defmodule FraytElixir.Repo.Migrations.ModifyActiveMatchesDefaultValue do
  use Ecto.Migration

  def change do
    alter table(:contracts) do
      modify :active_matches, :integer, default: nil
    end
  end
end
