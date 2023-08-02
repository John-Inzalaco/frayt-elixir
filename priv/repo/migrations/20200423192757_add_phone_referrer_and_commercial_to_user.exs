defmodule FraytElixir.Repo.Migrations.AddPhoneReferrerAndCommercialToUser do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :phone, :string
      add :referrer, :string
      add :commercial, :boolean
      add :texting, :boolean
    end
  end
end
