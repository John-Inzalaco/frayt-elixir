defmodule FraytElixir.Repo.Migrations.DEM500MigrateShipperAddrsToAddressesTable do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :address_id, references(:addresses, type: :binary_id, on_delete: :nilify_all)
    end

    execute &migrate_shipper_addrs_to_addresses/0, &migrate_shipper_addrs_from_addresses/0

    alter table(:shippers) do
      remove :city, :string
      remove :state, :string
      remove :zip, :string
      remove :address, :string
    end
  end

  defp migrate_shipper_addrs_to_addresses do
    repo().query!("""
    -- place_id is temporarily used to hold the reference to the shipper.
    INSERT INTO addresses
      (id, address, formatted_address, city, state, state_code, zip, country, country_code, place_id, inserted_at, updated_at)
    (
      SELECT gen_random_uuid() AS id,
             address,
             CONCAT(address, ', ', city, ', ', state, ' ', city) AS formatted_address,
             city,
             state,
             state AS state_code,
             zip,
             'United States',
             'US',
             id,
             NOW() AS inserted_at,
             NOW() AS updated_at
        FROM shippers
    )
    """)

    repo().query!("""
    UPDATE shippers s
       SET address_id = addrs.id
      FROM (
            SELECT
                   id,
                   place_id AS shipper_id
              FROM addresses
             WHERE place_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' -- only UUID locations are related to shippers
           ) addrs
     WHERE addrs.shipper_id::uuid = s.id::uuid
    """)

    repo().query!("""
    UPDATE addresses
       SET place_id = NULL
     WHERE place_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    """)
  end

  defp migrate_shipper_addrs_from_addresses do
    repo().query!("""
    UPDATE shippers s
       SET address = a.address,
           city = a.city,
           state = a.state,
           zip = a.zip
      FROM addresses a
     WHERE s.address_id = a.id
    """)

    repo().query!("""
    DELETE FROM addresses a
          WHERE a.id IN (SELECT address_id FROM shippers)
    """)
  end
end
