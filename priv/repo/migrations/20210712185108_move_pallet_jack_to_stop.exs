defmodule FraytElixir.Repo.Migrations.MovePalletJackToStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :needs_pallet_jack, :boolean
    end

    execute(&up_data/0, "")

    alter table(:matches) do
      remove :has_pallet_jack, :boolean
      remove :has_load_unload, :boolean
    end
  end

  defp up_data do
    repo().query!(
      """
      update match_stops
      set needs_pallet_jack = false;
      """,
      [],
      log: :info
    )
  end
end
