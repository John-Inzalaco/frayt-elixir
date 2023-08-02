defmodule FraytElixir.Repo.Migrations.AddSmsOptOutToDrivers do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :sms_opt_out, :boolean
    end
  end
end
