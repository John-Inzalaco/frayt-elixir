defmodule FraytElixir.Repo.Migrations.AddDurationTypesToContractSlas do
  use Ecto.Migration

  def change do
    alter table(:contract_slas) do
      add :duration_type, :string, default: nil
      add :min_duration, :string
      add :time, :time
      modify :duration, :string, null: true, from: :string
    end
  end
end
