defmodule FraytElixir.Repo.Migrations.AddBubbleAuthToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :auth_via_bubble, :boolean
    end
  end
end
