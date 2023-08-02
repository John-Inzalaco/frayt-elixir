defmodule FraytElixir.Repo.Migrations.MigrateRecipientFieldsToRecipient do
  use Ecto.Migration

  def change do
    execute &migrate_to_contacts/0, &migrate_from_contacts/0

    alter table(:match_stops) do
      remove :recipient_name, :string
      remove :recipient_email, :string
      remove :recipient_phone, :string
      remove :notify_recipient, :string
    end
  end

  defp migrate_from_contacts do
    repo().query!("""
    update match_stops
    set recipient_name = c.name, recipient_phone = substring(c.phone_number from '[0-9]+'), recipient_email = c.email, notify_recipient = c.notify, recipient_id = null
    from contacts as c
    where c.id = match_stops.recipient_id
    """)

    repo().query!("""
    delete from contacts
    WHERE not exists (
      select 1
      from matches as m
      where m.sender_id = contacts.id
    )
    """)
  end

  defp migrate_to_contacts do
    # Disable foreign key (technically all) checks
    repo().query!("ALTER TABLE match_stops DROP CONSTRAINT match_stops_recipient_id_fkey")

    repo().query!("""
    update match_stops set recipient_id = gen_random_uuid() where recipient_name is not null;
    """)

    repo().query!(
      """
      insert into contacts (id, name, phone_number, email, notify, inserted_at, updated_at)
      select s.recipient_id, s.recipient_name, LPAD(LPAD(s.recipient_phone, 11, '1'), 12, '+'), s.recipient_email, s.notify_recipient::boolean, NOW(), NOW()
      from match_stops as s
      where s.recipient_name is not null
      """,
      [],
      log: :info
    )

    repo().query!(
      "ALTER TABLE match_stops ADD CONSTRAINT match_stops_recipient_id_fkey FOREIGN KEY(recipient_id) REFERENCES contacts(id)"
    )
  end
end
