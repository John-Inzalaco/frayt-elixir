defmodule FraytElixir.Repo.Migrations.ChangeNotesToTextOnDriverBonus do
  use Ecto.Migration

  def change do
    alter table(:driver_bonuses) do
      modify :notes, :text
    end
  end
end
