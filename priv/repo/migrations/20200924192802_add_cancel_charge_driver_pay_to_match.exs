defmodule FraytElixir.Repo.Migrations.AddCancelChargeDriverPayToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :cancel_charge_driver_pay, :integer
    end
  end
end
