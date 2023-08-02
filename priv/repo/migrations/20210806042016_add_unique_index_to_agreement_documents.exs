defmodule FraytElixir.Repo.Migrations.AddUniqueIndexToAgreementDocuments do
  use Ecto.Migration

  def change do
    create index(:agreement_documents, [:type, :user_type], unique: true)
  end
end
