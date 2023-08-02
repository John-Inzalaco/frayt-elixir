defmodule FraytElixir.Repo.Migrations.AddDeliveryInformationToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :pickup_notes, :string
      add :delivery_notes, :string
      add :description, :text
      add :po, :string
      add :self_recipient, :boolean, default: false
      add :recipient_name, :string
      add :recipient_email, :string
      add :recipient_phone, :string
    end
  end
end
