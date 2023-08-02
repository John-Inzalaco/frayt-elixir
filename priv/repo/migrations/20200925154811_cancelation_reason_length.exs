defmodule Elixir.FraytElixir.Repo.Migrations.CancelationReasonLength do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      modify :cancel_reason, :text
    end
  end
end
