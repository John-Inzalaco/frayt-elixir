defmodule FraytElixir.Repo.Migrations.DEM386AddCancellationConfigToContracts do
  use Ecto.Migration

  def change do
    alter table(:contracts) do
      add :cancellation_pay_rules, :map
      add :allowed_cancellation_states, {:array, :string}
    end
  end
end
