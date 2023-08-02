defmodule FraytElixir.Repo.Migrations.AddNotifyRecipientToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :notify_recipient, :boolean
    end
  end
end
