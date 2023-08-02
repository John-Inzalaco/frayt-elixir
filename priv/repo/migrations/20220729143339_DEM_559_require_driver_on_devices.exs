defmodule FraytElixir.Repo.Migrations.DEM559RequireDriverOnDevices do
  use Ecto.Migration

  def up do
    remove_duplicate_devices()
    remove_orphan_devices()

    alter table(:driver_devices) do
      modify :driver_id, :binary_id, null: false
      modify :player_id, :string, null: false
    end

    create_if_not_exists unique_index(:driver_devices, [:player_id])
  end

  def down, do: nil

  defp remove_orphan_devices do
    # Pair as many orphaned devices as possible.
    execute """
    WITH to_update AS (
          SELECT d.id AS driver_id,
                 dd.id AS device_id
            FROM driver_devices dd
      RIGHT JOIN drivers d
              ON d.default_device_id = dd.id
           WHERE dd.driver_id IS NULL
    )
    UPDATE driver_devices AS dd
       SET driver_id = driver.driver_id
      FROM to_update AS driver
     WHERE driver.device_id = dd.id
    """

    # Remove devices that failed to pair
    #
    # Note: We can remove them because they are not in use,
    #       no driver has it marked as a default device and
    #       they are not used to send notifications.
    execute """
    DELETE FROM driver_devices dd WHERE dd.driver_id IS NULL
    """
  end

  defp remove_duplicate_devices do
    execute """
    WITH duplicate_devices AS (
    SELECT id,
           ROW_NUMBER() OVER(PARTITION BY player_id ORDER BY id) AS DuplicateCount
      FROM driver_devices dd
    )
    DELETE FROM driver_devices dd2
          WHERE dd2.id IN (
                           SELECT id
                             FROM duplicate_devices
                            WHERE DuplicateCount > 1
                          )
    """
  end
end
