defmodule FraytElixir.Repo.Migrations.AddUniqueConstraintOnMatchSlas do
  use Ecto.Migration

  def change do
    drop unique_index(:match_slas, [:match_id, :type, :driver_id])

    create unique_index(:match_slas, [:match_id, :type, :driver_id],
             where: "driver_id is not null"
           )

    create unique_index(:match_slas, [:match_id, :type], where: "driver_id is null")
  end
end
