defmodule FraytElixir.Repo.Migrations.RemoveMatchStopFieldsFromMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :weight
      remove :height
      remove :length
      remove :pieces
      remove :width
      remove :recipient_name
      remove :recipient_phone
      remove :recipient_email
      remove :destination_address_id
      remove :has_load_fee
      remove :load_fee_price
    end
  end
end
