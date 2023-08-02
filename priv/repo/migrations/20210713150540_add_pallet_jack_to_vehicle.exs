defmodule FraytElixir.Repo.Migrations.AddPalletJackToVehicle do
  use Ecto.Migration

  def change do
    alter table(:vehicles) do
      add :pallet_jack, :boolean
    end

    execute(&up_data/0, "")
  end

  defp up_data do
    repo().query!(
      """
      update vehicles
      set pallet_jack = false;
      """,
      [],
      log: :info
    )

    repo().query!(
      """
      update vehicles
      set lift_gate = false
      where lift_gate is null;
      """,
      [],
      log: :info
    )
  end
end
