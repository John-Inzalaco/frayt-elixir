defmodule FraytElixir.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :distance, :float
      add :base_price, :integer
      add :load_fee_price, :integer
      add :alert_headline, :string
      add :alert_description, :string
      add :markup, :boolean, default: false, null: false
      add :weight, :integer

      timestamps()
    end
  end
end
