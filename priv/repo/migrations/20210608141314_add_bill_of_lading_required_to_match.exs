defmodule FraytElixir.Repo.Migrations.AddBillOfLadingRequiredToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :bill_of_lading_required, :boolean
    end
  end
end
