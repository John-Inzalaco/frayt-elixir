defmodule FraytElixir.Repo.Migrations.AddShippersAssociationToAdmins do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :sales_rep_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end
  end
end
