defmodule FraytElixirWeb.Admin.SettingsLive do
  use FraytElixirWeb, :live_view
  use FraytElixirWeb.DataTable.Root

  @base_url "/admin/settings"

  @pages [
    profile: FraytElixirWeb.Admin.ProfileLive,
    users: FraytElixirWeb.Admin.UsersLive,
    agreements: FraytElixirWeb.Admin.AgreementsLive,
    contracts: FraytElixirWeb.Admin.ContractsLive
  ]

  @page_keys Keyword.keys(@pages)

  def mount(params, _session, socket) do
    {:ok,
     assign(socket, %{
       reset_password: Map.get(params, "reset_password", false),
       pages: available_pages(socket.assigns.current_user)
     })
     |> set_page(Map.get(params, "setting_page", :profile), params)}
  end

  def handle_params(%{"setting_page" => page} = params, _session, socket),
    do: {:noreply, set_page(socket, page, params)}

  def handle_params(_params, _session, socket), do: {:noreply, socket}

  def handle_event("change_page:" <> page, _event, socket) do
    {:noreply, update_page(socket, page)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.SettingsView.render("index.html", assigns)
  end

  defp set_page(socket, page, params) when is_binary(page),
    do: set_page(socket, String.to_existing_atom(page), params |> Map.delete("setting_page"))

  defp set_page(socket, page, params) do
    if page in available_pages(socket.assigns.current_user) and page in @page_keys do
      assign(socket, %{
        live_view: @pages[page],
        page: page,
        params: params
      })
    else
      redirect(socket, to: "#{@base_url}/profile")
    end
  end

  defp update_page(%{assigns: %{page: current_page}} = socket, page) do
    if Atom.to_string(current_page) == page do
      socket
    else
      push_patch(socket, to: "#{@base_url}/#{page}")
    end
  end

  defp available_pages(user) do
    if user_has_role(user, :admin) do
      @page_keys
    else
      [:profile, :contracts]
    end
  end
end
