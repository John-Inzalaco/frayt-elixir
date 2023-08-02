defmodule FraytElixirWeb.Admin.AddressesView do
  use FraytElixirWeb, :view
  alias FraytElixir.Shipment.Address

  def address_error_tag(%{source: nil} = form, field),
    do: error_tag(form, field)

  def address_error_tag(form, field) do
    case form.source.changes do
      %{^field => %Ecto.Changeset{errors: [_ | _]}} -> "Invalid address"
      _ -> error_tag(form, field)
    end
  end

  def address_input_value(form, field) do
    case input_value(form, field) do
      %{formatted_address: value} -> value
      %Ecto.Changeset{} = changeset -> Ecto.Changeset.get_field(changeset, :formatted_address)
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  def country_code_options, do: Address.country_codes() |> codes_to_options()
  def state_code_options, do: Address.state_codes() |> codes_to_options()

  def point_input_value(form, field, pos) when pos in [:lat, :lng] do
    case input_value(form, field) do
      %Geo.Point{coordinates: {lng, lat}} ->
        case pos do
          :lat -> lat
          :lng -> lng
        end

      _ ->
        nil
    end
  end

  defp codes_to_options(codes) do
    Enum.map(codes, fn {code, _name} -> {code, code} end)
  end
end
