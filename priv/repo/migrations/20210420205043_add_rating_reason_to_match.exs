defmodule FraytElixir.Repo.Migrations.AddRatingReasonToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :rating_reason, :string
    end
  end
end
