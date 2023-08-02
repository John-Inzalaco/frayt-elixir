defmodule FraytElixir.Repo.Migrations.AddDriverPayFieldsToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :driver_load_fee_price, :integer
      add :driver_total_pay, :integer
      add :driver_fees, :integer
    end

    rename table(:matches), :drivers_cut, to: :driver_base_price
  end
end
