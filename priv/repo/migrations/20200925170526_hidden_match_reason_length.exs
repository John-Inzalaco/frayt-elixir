defmodule FraytElixir.Repo.Migrations.HiddenMatchReasonLength do
  use Ecto.Migration

  def change do
    alter table(:hidden_matches) do
      modify :reason, :text
    end
  end
end
