defmodule FraytElixir.AdminSettingsTest do
  use FraytElixir.DataCase

  alias FraytElixir.AdminSettings
  alias AdminSettings.MetricSettings
  alias Ecto.Changeset

  describe "get_metric_settings" do
    test "gets settings" do
      insert(:metric_settings, fulfillment_goal: 12)

      assert %MetricSettings{fulfillment_goal: 12} = AdminSettings.get_metric_settings()
    end

    test "gets settings when none exist" do
      assert %MetricSettings{fulfillment_goal: 0} = AdminSettings.get_metric_settings()
    end
  end

  describe "change_metric_settings" do
    test "updates settings" do
      insert(:metric_settings, fulfillment_goal: 12)

      assert {:ok, %MetricSettings{fulfillment_goal: 49}} =
               AdminSettings.change_metric_settings(%{fulfillment_goal: 49})
    end

    test "creates settings when non existent" do
      assert {:ok, %MetricSettings{fulfillment_goal: 14}} =
               AdminSettings.change_metric_settings(%{fulfillment_goal: 14})
    end

    test "validates" do
      assert {:error,
              %Changeset{
                errors: [
                  fulfillment_goal:
                    {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]}
                ]
              }} = AdminSettings.change_metric_settings(%{fulfillment_goal: -1})
    end
  end
end
