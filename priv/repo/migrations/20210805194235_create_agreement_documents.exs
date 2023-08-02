defmodule FraytElixir.Repo.Migrations.CreateAgreementDocuments do
  use Ecto.Migration

  def change do
    create table(:agreement_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :user_type, :string
      add :type, :string
      add :content, :text

      add :parent_document_id,
          references(:agreement_documents, on_delete: :nilify_all, type: :binary_id)

      timestamps()
    end

    alter table(:user_agreements) do
      add :document_id, references(:agreement_documents, on_delete: :delete_all, type: :binary_id)
    end

    create index(:user_agreements, [:document_id])
  end
end
