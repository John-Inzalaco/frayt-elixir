defmodule FraytElixir.Repo.Migrations.AddAutoCancelOnDriverCancelTimeAfterAcceptanceToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :auto_cancel_on_driver_cancel_time_after_acceptance, :integer
    end
  end
end
