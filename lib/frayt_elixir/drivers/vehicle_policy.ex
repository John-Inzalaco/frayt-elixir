defmodule FraytElixir.Drivers.Vehicle.Policy do
  @moduledoc """
  Permissions for all things Vehicle related.
  """
  @behaviour Bodyguard.Policy
  alias FraytElixir.Drivers.Vehicle

  def authorize(_, nil, _) do
    # non-logged in users never have permission to do anything
    false
  end

  def authorize(_, %{id: driver_id}, %Vehicle{driver_id: driver_id}) do
    # Driver that "own" the Vehicle can do any action
    true
  end

  # anyone can create a Vehicle
  def authorize(:create, _, _), do: true

  # otherwise, you're not allowed to do anything to an Vehicle
  def authorize(_, _, _), do: false
end
