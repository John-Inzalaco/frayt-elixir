defmodule FraytElixir.Repo.Migrations.AddStateAbbrToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :state_abbr, :string
    end
  end
end
