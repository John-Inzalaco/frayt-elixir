defmodule FraytElixir.Repo.Migrations.AddAutoCancelOnDriverCancelToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :auto_cancel_on_driver_cancel, :boolean
    end
  end
end
