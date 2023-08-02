defmodule FraytElixir.Repo.Migrations.CreateBatchStateTransitions do
  use Ecto.Migration

  def change do
    create table(:batch_state_transitions) do
      add :from, :string
      add :to, :string
      add :notes, :text
      add :batch_id, references(:delivery_batches, on_delete: :delete_all, type: :binary_id)
      timestamps()
    end

    alter table(:match_state_transitions) do
      remove :transitioned_at, :utc_datetime
    end

    alter table(:match_stop_state_transitions) do
      remove :transitioned_at, :utc_datetime
    end

    create index(:batch_state_transitions, [:batch_id])
  end
end
