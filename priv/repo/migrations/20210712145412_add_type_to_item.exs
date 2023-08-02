defmodule FraytElixir.Repo.Migrations.AddTypeToItem do
  use Ecto.Migration

  def change do
    alter table(:match_stop_items) do
      add :type, :string
    end

    execute &up_data/0, ""
  end

  defp up_data do
    repo().query!(
      """
      update match_stop_items
      set type = 'item';
      """,
      [],
      log: :info
    )
  end
end
