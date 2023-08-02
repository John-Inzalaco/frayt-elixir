defmodule FraytElixir.Repo.Migrations.ModifyDataTypesToFloat do
  use Ecto.Migration

  def change do
    alter table(:match_stop_items) do
      modify :length, :float, from: :int
      modify :width, :float, from: :int
      modify :height, :float, from: :int
    end
  end
end
