defmodule FraytElixir.Repo.Migrations.AddWalletStateToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      remove :has_wallet, :boolean
      add :wallet_state, :string
    end
  end
end
