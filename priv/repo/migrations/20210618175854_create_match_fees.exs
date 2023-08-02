defmodule FraytElixir.Repo.Migrations.CreateMatchFees do
  use Ecto.Migration

  def change do
    create table(:match_fees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :integer
      add :driver_amount, :integer
      add :type, :string
      add :description, :string
      add :match_id, references(:matches, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:match_fees, [:match_id])
  end
end
