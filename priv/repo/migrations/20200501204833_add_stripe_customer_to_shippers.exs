defmodule FraytElixir.Repo.Migrations.AddStripeCustomerToShippers do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :stripe_customer_id, :string
    end
  end
end
