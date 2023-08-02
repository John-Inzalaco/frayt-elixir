defmodule FraytElixir.AdminSettings.MetricSettings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "metric_settings" do
    field :fulfillment_goal, :integer, default: 0
    field :monthly_revenue_goal, :integer, default: 0
    field :sla_goal, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(metric_settings, attrs) do
    metric_settings
    |> cast(attrs, [:fulfillment_goal, :monthly_revenue_goal, :sla_goal])
    |> validate_required([:fulfillment_goal, :monthly_revenue_goal, :sla_goal])
    |> validate_number(:fulfillment_goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:monthly_revenue_goal, greater_than_or_equal_to: 0)
    |> validate_number(:sla_goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
