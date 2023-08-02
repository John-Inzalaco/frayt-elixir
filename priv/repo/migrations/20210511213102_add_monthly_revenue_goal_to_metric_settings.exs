defmodule FraytElixir.Repo.Migrations.AddMonthlyRevenueGoalToMetricSettings do
  use Ecto.Migration

  def change do
    alter table(:metric_settings) do
      add :monthly_revenue_goal, :integer
    end
  end
end
