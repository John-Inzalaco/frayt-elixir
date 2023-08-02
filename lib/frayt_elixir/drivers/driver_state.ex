defmodule FraytElixir.Drivers.DriverState do
  @states [
    :disabled,
    :rejected,
    :registered,
    :approved,
    :screening,
    :pending_approval,
    :applying
  ]

  def all_states, do: @states

  def disabled_states, do: [:rejected, :disabled]
  def active_states, do: [:approved, :registered]

  use FraytElixir.Type.Enum, types: @states
end
