defmodule FraytElixir.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :phone_number, :string
      add :email, :string
      add :notify, :boolean

      timestamps()
    end

    alter table(:matches) do
      add :sender_id, references(:contacts, type: :binary_id)
    end

    alter table(:match_stops) do
      add :recipient_id, references(:contacts, type: :binary_id)
    end

    create index(:matches, [:sender_id])
    create index(:match_stops, [:recipient_id])
  end
end
