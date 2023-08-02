defmodule FraytElixir.Repo.Migrations.RenameStateCodeInAddresses do
  use Ecto.Migration

  def change do
    rename(table(:addresses), :state_abbr, to: :state_code)
  end
end
