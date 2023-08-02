defmodule FraytElixirWeb.SessionFallbackController do
  @moduledoc """
  Translates session controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """

  use FraytElixirWeb, :controller

  import Phoenix.Naming, only: [humanize: 1]
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.FallbackController

  @doc """
  For requests coming from the admin tool
  """
  def call(%{path_info: [path | _rest]} = conn, error)
      when path in ["sessions", "admin"],
      do: handle_admin_call(conn, error)

  def call(conn, error), do: FallbackController.call(conn, error)

  def handle_admin_call(conn, {:error, %Ecto.Changeset{errors: [error | _rest]}}) do
    {field, {msg, _}} = error

    render_reset_page(conn, "#{humanize(field)} #{msg}")
  end

  def handle_admin_call(conn, %Ecto.Changeset{} = cs),
    do: render_reset_page(conn, DisplayFunctions.humanize_errors(cs))

  def handle_admin_call(conn, {:error, :invalid_credentials}),
    do: render_reset_page(conn, "Invalid password reset link")

  def handle_admin_call(conn, {:error, msg}) when is_binary(msg),
    do: render_reset_page(conn, msg)

  def handle_admin_call(conn, _error),
    do: render_reset_page(conn, "Unexpected error")

  defp render_reset_page(conn, msg),
    do:
      conn
      |> put_flash(:error, msg)
      |> render("reset.html", get_default_params(conn))

  defp get_default_params(conn) do
    attrs = Map.take(conn.params, ["email", "password_reset_code"])

    %{email: attrs["email"], password_reset_code: attrs["password_reset_code"]}
  end
end
