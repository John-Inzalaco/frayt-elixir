defmodule FraytElixir.Repo.Migrations.AddSlackIdToAdminUser do
  use Ecto.Migration

  def change do
    alter table(:admin_users) do
      add :slack_id, :string
    end
  end
end
