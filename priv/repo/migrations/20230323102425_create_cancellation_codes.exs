defmodule FraytElixir.Repo.Migrations.CreateCancellationCodes do
  use Ecto.Migration

  def change do
    create table(:cancellation_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contract_id, references(:contracts, on_delete: :delete_all, type: :binary_id)
      add :code, :string
      add :message, :string
      timestamps()
    end
  end
end
