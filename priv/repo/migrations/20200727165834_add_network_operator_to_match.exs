defmodule FraytElixir.Repo.Migrations.AddNetworkOperatorToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :network_operator_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end
  end
end
