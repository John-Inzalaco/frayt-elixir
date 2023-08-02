defmodule FraytElixir.Repo.Migrations.AddAddressesToMatch do
  use Ecto.Migration

  def change do
    alter table("matches") do
      add :origin_address_id, references(:addresses)
      add :destination_address_id, references(:addresses)
    end
  end
end
