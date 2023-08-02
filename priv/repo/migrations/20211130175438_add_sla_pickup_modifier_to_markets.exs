defmodule FraytElixir.Repo.Migrations.AddSlaPickupModifierToMarkets do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :sla_pickup_modifier, :integer
    end

    execute &populate_default/0, ""
  end

  defp populate_default do
    repo().query!("update markets set sla_pickup_modifier = 0")
    repo().query!("update matches set travel_duration = 0")
  end
end
