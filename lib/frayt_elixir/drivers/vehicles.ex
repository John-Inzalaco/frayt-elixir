defmodule FraytElixir.Drivers.Vehicles do
  @moduledoc """
  The Businesses context for an Vehicle.
  """
  alias FraytElixir.Repo
  alias FraytElixir.Drivers.Vehicle

  defdelegate authorize(action, user, params), to: FraytElixir.Drivers.Vehicle.Policy

  @doc """
  Creates a vehicle.

  ## Examples

      iex> create_vehicle(%{field: value})
      {:ok, %Vehicle{}}

      iex> create_vehicle(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vehicle(attrs \\ %{}) do
    %Vehicle{}
    |> Vehicle.changeset(attrs)
    |> Repo.insert()
  end

  def update_vehicle(%Vehicle{} = vehicle, attrs \\ %{}) do
    vehicle
    |> Vehicle.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single vehicle.

  Raises `Ecto.NoResultsError` if the Vehicle does not exist.

  ## Examples

      iex> get_vehicle!(123)
      %Vehicle{}

      iex> get_vehicle!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vehicle!(id), do: Repo.get!(Vehicle, id)
end
