defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-152-ShowNetworkOpsAssignedToMatchInDriverApp" do
  use Ecto.Migration

  def change do
    alter table(:admin_users) do
      add :phone_number, :string
    end
  end
end
