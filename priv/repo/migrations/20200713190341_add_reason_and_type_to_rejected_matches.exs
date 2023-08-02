defmodule FraytElixir.Repo.Migrations.AddReasonAndTypeToRejectedMatches do
  use Ecto.Migration

  def change do
    alter table(:rejected_matches) do
      add :reason, :string
      add :type, :string
    end
  end
end
