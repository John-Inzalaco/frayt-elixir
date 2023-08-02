defmodule FraytElixir.Repo.Migrations.AddStateToAgreementDocument do
  use Ecto.Migration

  def change do
    alter table(:agreement_documents) do
      add :state, :string
    end
  end
end
