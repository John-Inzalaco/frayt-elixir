defmodule FraytElixir.Repo.Migrations.CreateDefaultPartitions do
  use Ecto.Migration
  import FraytElixir.Helpers.TablePartitioning

  def up do
    create_default_partition(:sent_notifications)
    create_default_partition(:driver_locations, if_not_exists: true)
  end

  def down do
    # do not remove driver_locations on down, since other tables now rely on this
    drop_default_partition(:sent_notifications)
  end
end
