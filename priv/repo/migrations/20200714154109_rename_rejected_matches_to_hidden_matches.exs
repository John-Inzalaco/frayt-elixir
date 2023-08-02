defmodule FraytElixir.Repo.Migrations.RenameRejectedMatchesToHiddenMatches do
  use Ecto.Migration

  def change do
    rename table("rejected_matches"), to: table("hidden_matches")
  end
end
