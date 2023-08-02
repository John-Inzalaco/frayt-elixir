defmodule FraytElixirWeb.Admin.DriversController do
  use FraytElixirWeb, :controller

  alias FraytElixir.DriverDocuments

  def vehicle_photos(conn, %{"vehicle_photos" => photos} = params) do
    %{
      "driver_id" => driver_id,
      "vehicle_id" => vehicle_id
    } = params

    Enum.each(photos, fn {type, attrs} ->
      DriverDocuments.create_vehicle_document(%{
        type: type,
        state: :approved,
        expires_at: Map.get(attrs, "expires_at"),
        document: Map.get(attrs, "document"),
        vehicle_id: vehicle_id
      })
    end)

    conn |> redirect(to: "/admin/drivers/#{driver_id}")
  end

  def driver_photos(conn, %{"id" => driver_id, "driver_photos" => photos}) do
    Enum.each(photos, fn {type, attrs} ->
      DriverDocuments.create_driver_document(%{
        type: type,
        state: :approved,
        expires_at: Map.get(attrs, "expires_at"),
        document: Map.get(attrs, "document"),
        driver_id: driver_id
      })
    end)

    conn |> redirect(to: "/admin/drivers/#{driver_id}")
  end
end
