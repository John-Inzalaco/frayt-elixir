defmodule FraytElixir.Repo.Migrations.AddDriverToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :payee_account_id, references(:seller_accounts, type: :binary_id, on_delete: :nothing)
      add :accepted_at, :utc_datetime
    end
  end
end
