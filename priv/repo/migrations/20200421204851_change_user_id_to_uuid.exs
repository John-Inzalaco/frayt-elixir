defmodule FraytElixir.Repo.Migrations.ChangeUserIdToUuid do
  use Ecto.Migration

  def change do
    drop_if_exists table(:users)

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string
      add :hashed_password, :string

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
