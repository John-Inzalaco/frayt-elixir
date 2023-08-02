defmodule FraytElixir.Repo.Migrations.AddAppVersionToDriverDevice do
  use Ecto.Migration

  def change do
    alter table(:driver_devices) do
      add :app_version, :string
      add :app_revision, :string
      add :app_build_number, :integer
    end
  end
end
