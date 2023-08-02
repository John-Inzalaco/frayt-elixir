defmodule FraytElixir.Repo.Migrations.ConvertDocumentUserTypeToArray do
  use Ecto.Migration

  def change do
    alter table(:agreement_documents) do
      remove :user_type, :string
      add :user_types, {:array, :string}
    end
  end
end
