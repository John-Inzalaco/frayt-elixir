defmodule FraytElixir.Repo.Migrations.AddNamesToShipper do
  use Ecto.Migration

  def change do
    alter table("shippers") do
      add :first_name, :string
      add :last_name, :string
    end
  end
end
