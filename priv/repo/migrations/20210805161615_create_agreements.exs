defmodule FraytElixir.Repo.Migrations.CreateAgreements do
  use Ecto.Migration

  def change do
    create table(:user_agreements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agreed, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:user_agreements, [:user_id])
  end
end
