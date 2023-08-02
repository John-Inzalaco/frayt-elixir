defmodule FraytElixirWeb.Admin.CompaniesView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  import FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.AdminAlerts
  alias FraytElixir.Accounts.{Schedule, APIVersion, AdminUser}
  alias FraytElixir.Contracts.Contract

  def shipper_count(locations) do
    Enum.reduce(locations, 0, fn location, acc -> acc + Enum.count(location.shippers) end)
  end

  def match_count(locations) do
    Enum.reduce(locations, 0, fn location, acc ->
      acc +
        Enum.reduce(location.shippers, 0, fn shipper, matches ->
          matches + Enum.count(shipper.matches)
        end)
    end)
  end

  def set_live_view(default_form) do
    if default_form == :shipper,
      do: FraytElixirWeb.AdminSearchShipper,
      else: FraytElixirWeb.AdminAddCompanyLive
  end

  def days, do: ~w[sunday monday tuesday wednesday thursday friday saturday]a

  def is_schedule(%Schedule{}), do: true
  def is_schedule(_), do: false

  def display_webhook_config(company, key), do: Map.get(company.webhook_config || %{}, key)

  def private_text(nil, _), do: "N/A"

  def private_text(string, visible_length) do
    length = String.length(string)
    padding = max(length - visible_length, 4)
    visible_string = string |> String.slice(padding, length)
    String.pad_leading(visible_string, length, ["*"])
  end

  def display_text(nil), do: "N/A"
  def display_text(string), do: string
end
