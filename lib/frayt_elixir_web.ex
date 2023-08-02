defmodule FraytElixirWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use FraytElixirWeb, :controller
      use FraytElixirWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: FraytElixirWeb

      import Plug.Conn
      import FraytElixirWeb.Gettext

      import Phoenix.LiveView.Controller

      alias FraytElixirWeb.OpenApiHelper
      alias FraytElixirWeb.Router.Helpers, as: Routes
      alias FraytElixirWeb.API.V2x1.Router.Helpers, as: RoutesApiV2_1
      alias FraytElixirWeb.API.V2x2.Router.Helpers, as: RoutesApiV2_2
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/frayt_elixir_web/templates",
        namespace: FraytElixirWeb

      use Appsignal.Phoenix.View

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import Phoenix.LiveView.Helpers
      import FraytElixirWeb.LiveViewHelpers
      import FraytElixirWeb.FormHelpers

      import FraytElixirWeb.ErrorHelpers
      import FraytElixirWeb.Gettext
      import FraytElixirWeb.MapHelper
      import FraytElixirWeb.SessionHelper, only: [user_has_role: 2]
      alias FraytElixirWeb.Router.Helpers, as: Routes
      alias FraytElixirWeb.API.V2x1.Router.Helpers, as: RoutesApiV2_1
      alias FraytElixirWeb.API.V2x2.Router.Helpers, as: RoutesApiV2_2
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {FraytElixirWeb.LayoutView, "live.html"}

      use FraytElixirWeb.FormEvents
      use FraytElixirWeb.AssignCurrentUser
      use FraytElixirWeb.DarkModeEvents
      use FraytElixirWeb.TimeZoneEvents
      import FraytElixirWeb.SessionHelper, only: [user_has_role: 2]
      alias FraytElixirWeb.Router.Helpers, as: Routes
    end
  end

  def live_modal do
    quote do
      use Phoenix.LiveView,
        layout: {FraytElixirWeb.LayoutView, "live.html"}

      use FraytElixirWeb.FormEvents
    end
  end

  def router do
    quote do
      import Phoenix.LiveView.Router

      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Redirect
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import FraytElixirWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
