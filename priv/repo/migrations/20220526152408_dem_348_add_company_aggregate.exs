defmodule FraytElixir.Repo.Migrations.Dem348AddCompanyAggregate do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add_if_not_exists(:revenue, :integer, default: 0, null: false)
      add_if_not_exists(:match_count, :integer, default: 0, null: false)
    end
  end
end
