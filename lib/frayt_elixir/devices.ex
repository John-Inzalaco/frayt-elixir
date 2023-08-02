defmodule FraytElixir.Devices do
  @moduledoc """
  Functions for managing the Driver's devices.

  The Driver Devices table stores the information about
  version, operative system, os model, and others.
  """
  import Ecto.Query

  alias FraytElixir.Repo
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Devices.DriverDevice

  @doc """
  Returns a %DriverDevice{} for a given id.
  """
  def get_device!(nil), do: nil

  def get_device!(id) do
    qry = from c in DriverDevice, where: c.id == ^id

    Repo.one!(qry)
  end

  @doc """
  Creates a Driver DriverDevice if there is none, or updates existing one.

  ## Examples
    iex> upsert_driver_device(%{field: value}, %{} = driver)
    {:ok, %DriverDevice{}}

    iex> upsert_driver_device(%{field: bad_value}, %{} = driver)
    {:error, %Ecto.Changeset{}}
  """
  def upsert_driver_device(driver, attrs) do
    attrs = Map.put(attrs, :driver_id, driver.id)
    device_uuid = Map.get(attrs, :device_uuid, nil)

    device =
      case get_device_by_device_uuid(driver.id, device_uuid) do
        nil -> %DriverDevice{}
        device -> device
      end

    changeset = DriverDevice.changeset(device, attrs)

    with {:ok, device} <- Repo.insert_or_update(changeset) do
      set_default_driver_device(driver, device)
    end
  end

  defp set_default_driver_device(
         %Driver{default_device_id: default_device_id} = driver,
         %DriverDevice{id: device_id} = device
       )
       when device_id == default_device_id,
       do: {:ok, %{driver | default_device: device}}

  defp set_default_driver_device(driver, device),
    do:
      driver
      |> Repo.preload(:default_device)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:default_device, device)
      |> Repo.update()

  defp get_device_by_device_uuid(driver_id, device_uuid)
       when not is_nil(driver_id) and not is_nil(device_uuid) do
    qry =
      from d in DriverDevice,
        where: d.device_uuid == ^device_uuid and d.driver_id == ^driver_id

    Repo.one(qry)
  end
end
