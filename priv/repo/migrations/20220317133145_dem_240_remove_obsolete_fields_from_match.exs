defmodule FraytElixir.Repo.Migrations.DEM240RemoveObsoleteFieldsFromMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :alert_headline, :string
      remove :alert_description, :string
      remove :old_match_id, :text
      remove :accepted_at, :utc_datetime
      remove :origin_place, :string
    end

    alter table(:match_stops) do
      remove :destination_place, :string
    end
  end
end
