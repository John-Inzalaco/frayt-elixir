defmodule FraytElixir.Repo.Migrations.DEM888EnableFuzzystrmatchExtension do
  use Ecto.Migration

  def change do
    execute(
      "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch",
      "DROP EXTENSION IF EXISTS fuzzystrmatch"
    )

    execute(
      "CREATE extension IF NOT EXISTS pg_trgm",
      "DROP EXTENSION IF EXISTS pg_trgm"
    )
  end
end
