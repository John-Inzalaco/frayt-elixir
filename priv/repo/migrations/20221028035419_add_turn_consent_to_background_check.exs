defmodule FraytElixir.Repo.Migrations.AddTurnConsentToBackgroundCheck do
  use Ecto.Migration

  def change do
    alter table(:background_checks) do
      add :turn_consent_url, :text
    end
  end
end
