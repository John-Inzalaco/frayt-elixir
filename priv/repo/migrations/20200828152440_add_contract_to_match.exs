defmodule FraytElixir.Repo.Migrations.AddContractToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :contract, :string
    end
  end
end
