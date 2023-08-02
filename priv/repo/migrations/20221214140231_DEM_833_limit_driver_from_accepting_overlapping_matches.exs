defmodule FraytElixir.Repo.Migrations.LimitDriverFromAcceptingOverlappingMatches do
  use Ecto.Migration

  def change do
    alter table(:contracts) do
      add :active_matches, :integer, default: 0
      add :active_match_factor, :string, default: "delivery_duration"
      add :active_match_duration, :integer
    end
  end
end
