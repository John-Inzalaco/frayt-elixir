defmodule FraytElixir.Repo.Migrations.RenameStripeIdToExternalId do
  use Ecto.Migration

  def change do
    rename table(:payment_transactions), :stripe_id, to: :external_id
  end
end
