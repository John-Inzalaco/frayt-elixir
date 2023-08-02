defmodule FraytElixir.Repo.Migrations.AddSelfSenderToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :self_sender, :boolean
    end

    execute(&up_data/0, "")
  end

  defp up_data do
    repo().query!(
      """
      update matches
      set self_sender = true where self_sender is null;
      """,
      [],
      log: :info
    )
  end
end
