defmodule FraytElixir.Repo.Migrations.AddExpirationDatesToDriverAndVehicle do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :license_expiration_date, :date
    end

    alter table(:vehicles) do
      add :registration_expiration_date, :date
      add :insurance_expiration_date, :date
    end
  end
end
