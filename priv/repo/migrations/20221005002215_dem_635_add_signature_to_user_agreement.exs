defmodule FraytElixir.Repo.Migrations.Dem635AddSignatureToUserAgreement do
  use Ecto.Migration

  def change do
    alter table(:user_agreements) do
      add :signature, :string
    end
  end
end
