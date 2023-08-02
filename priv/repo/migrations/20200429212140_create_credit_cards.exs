defmodule FraytElixir.Repo.Migrations.CreateCreditCards do
  use Ecto.Migration

  def change do
    create table(:credit_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_token, :string
      add :stripe_card, :string
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :nothing)
      add :last4, :string

      timestamps()
    end

    create index(:credit_cards, [:shipper_id])
  end
end
