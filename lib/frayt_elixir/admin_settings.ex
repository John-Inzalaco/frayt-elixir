defmodule FraytElixir.AdminSettings do
  @moduledoc """
  The AdminSettings context.
  """

  import Ecto.Query, warn: false
  alias FraytElixir.Repo

  alias FraytElixir.AdminSettings.MetricSettings

  def get_metric_settings do
    MetricSettings
    |> first()
    |> Repo.one()
    |> case do
      nil -> %MetricSettings{}
      metric_settings -> metric_settings
    end
  end

  def change_metric_settings(attrs) do
    get_metric_settings()
    |> MetricSettings.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
