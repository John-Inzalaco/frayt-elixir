defmodule :"Elixir.FraytElixir.Repo.Migrations.Dem-630-preapproval-questionnaire-screen-market-selection" do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :now_hiring, :boolean
    end
  end
end
