defmodule FraytElixir.Repo.Migrations.AddAutoCancelTimeToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :auto_cancel_time, :integer, default: 120_000
    end
  end
end
