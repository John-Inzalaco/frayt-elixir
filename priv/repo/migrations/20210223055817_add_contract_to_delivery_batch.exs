defmodule FraytElixir.Repo.Migrations.AddContractToDeliveryBatch do
  use Ecto.Migration

  def change do
    alter table(:delivery_batches) do
      add :contract, :string
    end
  end
end
