defmodule FraytElixir.Repo.Migrations.AddTimeSurchargeToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :time_surcharge, :float
    end
  end
end
