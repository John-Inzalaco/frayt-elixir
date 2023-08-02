defmodule FraytElixirWeb.LayoutView do
  use FraytElixirWeb, :view

  alias FraytElixir.Accounts.{User, AdminUser}
  alias FraytElixirWeb.SessionHelper

  def activelink_class(conn, path) do
    current_path = Path.join(["/" | conn.path_info])

    if current_path =~ path do
      "active-link"
    else
      ""
    end
  end

  def is_dark_theme(%User{admin: %AdminUser{site_theme: :dark}}), do: true
  def is_dark_theme(_), do: false

  def get_theme(conn) do
    case SessionHelper.get_current_user(conn) do
      %User{admin: %AdminUser{site_theme: site_theme}} when not is_nil(site_theme) ->
        Atom.to_string(site_theme)

      _ ->
        "light"
    end
  end

  def theme_style(conn), do: "/css/#{get_theme(conn)}.css"

  def theme_class(conn), do: "theme-#{get_theme(conn)}"

  def live_class(conn) do
    if is_live_view(conn) do
      "live-page"
    end
  end

  def is_live_view(conn), do: !!Map.get(conn.assigns, :live_module)

  def nav_link(conn, path, label) do
    assigns = %{
      class: activelink_class(conn, path),
      path: path,
      label: label
    }

    ~L"""
      <a href="<%= @path %>" class="<%= @class %>"><%= @label %></a>
    """
  end
end
