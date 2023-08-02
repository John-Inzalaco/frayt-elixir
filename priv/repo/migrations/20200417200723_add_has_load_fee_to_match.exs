defmodule FraytElixir.Repo.Migrations.AddHasLoadFeeToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :has_load_fee, :boolean, default: false
    end
  end
end
