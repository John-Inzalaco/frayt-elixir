defmodule FraytElixir.Repo.Migrations.AddSellerAccountAndAmountToPaymentTransaction do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      add :amount, :integer
      add :seller_account_id, references(:seller_accounts, type: :binary_id, on_delete: :nothing)
    end
  end
end
