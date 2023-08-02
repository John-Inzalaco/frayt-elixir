defmodule FraytElixirWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use FraytElixirWeb, :controller

  alias FraytElixirWeb.ErrorCodeHelper

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(FraytElixirWeb.ChangesetView)
    |> render("error_message.json", changeset: changeset)
  end

  def call(conn, {:error, {code, identifier}, %Ecto.Changeset{} = changeset, data}),
    do:
      call(
        conn,
        {:error, Atom.to_string(code) <> "_#{identifier}", changeset, data}
      )

  def call(conn, {:error, code, %Ecto.Changeset{} = changeset, _data}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(FraytElixirWeb.ChangesetView)
    |> render("error_message.json", changeset: changeset, code: code)
  end

  def call(conn, {:error, _code, %Stripe.Error{} = error, _data}), do: call(conn, {:error, error})

  def call(conn, {:error, code, message, _data}) when is_binary(message) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(FraytElixirWeb.ErrorView)
    |> render("error_code.json", message: message, code: code)
  end

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(FraytElixirWeb.ChangesetView)
    |> render("error_message.json", changeset: changeset)
  end

  def call(conn, {:error, %Stripe.Error{} = error}),
    do:
      conn
      |> put_status(:unprocessable_entity)
      |> put_view(FraytElixirWeb.ErrorView)
      |> render("stripe_error.json", error: error)

  def call(conn, {:error, %Jason.DecodeError{}}),
    do: call(conn, {:error, "Failed to parse JSON"})

  def call(conn, {:error, type}) when is_atom(type), do: handle_error(conn, type)

  def call(conn, {:error, message}) when is_bitstring(message),
    do: handle_error(conn, :unprocessable_entity, message)

  def call(conn, {:error, type, message}) when is_atom(type),
    do: handle_error(conn, type, message)

  defp handle_error(conn, type) do
    message = ErrorCodeHelper.get_error_message(type)
    handle_error(conn, type, message)
  end

  defp handle_error(conn, type, message) do
    status = ErrorCodeHelper.get_error_status(type)

    conn
    |> put_status(status)
    |> put_view(FraytElixirWeb.ErrorView)
    |> render("error_code.json", message: message, code: type)
    |> halt
  end
end
