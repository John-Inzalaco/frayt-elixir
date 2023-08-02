defmodule FraytElixir.Repo.Migrations.AddSelfRecipientToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :self_recipient
    end

    alter table(:match_stops) do
      add :self_recipient, :boolean, default: false
    end
  end
end
