defmodule FraytElixirWeb.LiveComponent.MarketFormComponent do
  use Phoenix.LiveComponent
  alias FraytElixir.Markets
  alias FraytElixir.Markets.Market
  alias Ecto.Changeset
  alias FraytElixir.Repo
  alias FraytElixir.Convert

  def mount(socket) do
    {:ok, assign(socket, %{changeset: nil})}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    changeset = market_changeset(socket)

    {:ok, assign(socket, Map.put(assigns, :changeset, changeset))}
  end

  def handle_event("cancel", _, socket) do
    send(self(), :cancel_change)
    {:noreply, assign(socket, %{changeset: nil})}
  end

  def handle_event("change_market", %{"market" => attrs}, socket) do
    changeset =
      Market.changeset(socket.assigns.market, convert_attrs(attrs))
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, %{changeset: changeset})}
  end

  def handle_event("save_market", %{"market" => attrs}, socket) do
    attrs = convert_attrs(attrs)

    changeset = Market.changeset(socket.assigns.market, attrs)

    case Repo.insert_or_update(changeset) do
      {:ok, _market} ->
        send(self(), :markets_updated)
        {:noreply, assign(socket, :changeset, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete_market", _, socket) do
    case Markets.delete_market(socket.assigns.market) do
      {:ok, _market} ->
        send(self(), :markets_updated)
        {:noreply, assign(socket, :changeset, nil)}

      _ ->
        {:noreply, socket}
    end
  end

  @zip_fields [:id, :zip]

  def handle_event("remove_zip_" <> index, _, %{assigns: %{changeset: changeset}} = socket) do
    index = String.to_integer(index)

    zips =
      changeset
      |> Changeset.get_field(:zip_codes, [])
      |> Enum.with_index()
      |> Enum.reject(fn {_zip, i} -> i == index end)
      |> Enum.map(fn {zip, _i} -> Map.take(zip, @zip_fields) end)

    changeset = Changeset.change(changeset, %{zip_codes: zips})

    {:noreply, assign(socket, %{changeset: changeset})}
  end

  def handle_event("add_zip", _event, socket) do
    %{assigns: %{changeset: changeset}} = socket

    zips =
      changeset
      |> Changeset.get_field(:zip_codes, [])
      |> Enum.map(&Map.take(&1, @zip_fields))
      |> Enum.concat([%{}])

    changeset = Changeset.put_change(changeset, :zip_codes, zips)

    {:noreply, assign(socket, %{changeset: changeset})}
  end

  defp convert_attrs(attrs) do
    sla_pickup_mod =
      attrs
      |> Map.get("sla_pickup_modifier")
      |> Convert.to_integer() || 0

    attrs
    |> Map.put("sla_pickup_modifier", sla_pickup_mod * 60)
  end

  defp market_changeset(socket, attrs \\ %{}) do
    market = socket.assigns.market || %Market{}
    Market.changeset(market, attrs)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MarketsView.render("_market_form.html", assigns)
  end
end
