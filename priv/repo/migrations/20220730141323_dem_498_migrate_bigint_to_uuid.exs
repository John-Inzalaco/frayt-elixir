defmodule FraytElixir.Repo.Migrations.DEM498MigrateBigintToUuid do
  use Ecto.Migration

  def change do
    alter table(:batch_state_transitions) do
      add :uuid, :binary_id, primary: true, default: fragment("gen_random_uuid()")
      remove :id, :bigint, primary: true
    end

    alter table(:hidden_matches) do
      add :uuid, :binary_id, primary: true, default: fragment("gen_random_uuid()")
      remove :id, :bigint, primary: true
    end

    alter table(:match_state_transitions) do
      add :uuid, :binary_id, primary: true, default: fragment("gen_random_uuid()")
      remove :id, :bigint, primary: true
    end

    alter table(:match_stop_state_transitions) do
      add :uuid, :binary_id, primary: true, default: fragment("gen_random_uuid()")
      remove :id, :bigint, primary: true
    end

    rename table(:batch_state_transitions), :uuid, to: :id
    rename table(:hidden_matches), :uuid, to: :id
    rename table(:match_state_transitions), :uuid, to: :id
    rename table(:match_stop_state_transitions), :uuid, to: :id
  end
end
