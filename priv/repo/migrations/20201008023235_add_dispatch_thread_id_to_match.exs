defmodule FraytElixir.Repo.Migrations.AddDispatchThreadIdToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :slack_thread_id, :string
    end
  end
end
