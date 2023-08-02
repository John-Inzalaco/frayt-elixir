defmodule FraytElixir.Repo.Migrations.AddLiftGateToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :lift_gate, :boolean
    end
  end
end
