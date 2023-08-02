defmodule FraytElixirWeb.SessionController do
  use FraytElixirWeb, :controller

  alias FraytElixir.{Accounts, Drivers}
  alias FraytElixir.Accounts.User
  alias FraytElixir.Drivers.Driver
  alias FraytElixirWeb.Plugs.Auth
  import FraytElixirWeb.UrlHelper
  import FraytElixir.Guards

  action_fallback(FraytElixirWeb.SessionFallbackController)

  plug(:put_layout, "unauthenticated.html")

  use Params

  defparams(
    reset_password_params(%{
      email!: :string,
      password_reset_code!: :string,
      password!: :string,
      password_confirmation!: :string
    })
  )

  def authenticate_shipper(conn, %{"email" => email, "password" => password}) do
    with {:ok, %User{} = user} <- Accounts.authenticate(email, password, :shipper),
         {:ok, token, _claims} <- FraytElixir.Guardian.encode_and_sign(user) do
      render(conn, "authenticate_shipper.json", token: token, shipper: user.shipper)
    end
  end

  def authenticate_driver(conn, %{"email" => email, "password" => password})
      when not is_nil(email) do
    with {:ok, %User{} = user} <- Accounts.authenticate(email, password, :driver),
         {:ok, %Driver{} = driver} <- Drivers.get_driver_for_user(user),
         {:ok, _revoked_qty} <- FraytElixir.Guardian.revoke_all(user, %{}),
         {:ok, token, _claims} <-
           FraytElixir.Guardian.encode_and_sign(user, %{}, ttl: {4, :weeks}) do
      render(conn, "authenticate_driver.json", token: token, driver: driver, user: user)
    end
  end

  def authenticate_driver(conn, %{"email" => email, "code" => code})
      when not is_nil(email) do
    with {:ok, %User{} = user} <- Accounts.verify_code(email, code),
         {:ok, %Driver{} = driver} <- Drivers.get_driver_for_user(user),
         {:ok, _revoked_qty} <- FraytElixir.Guardian.revoke_all(user, %{}),
         {:ok, token, _claims} <-
           FraytElixir.Guardian.encode_and_sign(user, %{}, ttl: {4, :weeks}) do
      render(conn, "authenticate_driver.json", token: token, driver: driver)
    end
  end

  def authenticate_driver(_, _),
    do: {:error, :invalid_credentials}

  def logout(conn, _params) do
    jwt = Guardian.Plug.current_token(conn)
    FraytElixir.Guardian.revoke(jwt)

    conn
    |> put_status(:ok)
    |> render("logout.json", message: "Token has been invalidated")
  end

  def new(conn, %{"password_reset_code" => code, "email" => email}) do
    params = %{password_reset_code: code, email: email}

    case Accounts.get_user(params) do
      {:ok, _user} ->
        render(conn, "reset.html", params)

      _ ->
        {:error, "Invalid reset password link"}
    end
  end

  def new(conn, params) do
    if Auth.current_user(conn) do
      logged_in_redirect(conn, params)
    else
      render(conn, "new.html")
    end
  end

  def create(conn, %{"session" => %{"password_reset_code" => code} = params}) do
    default_params = %{password_reset_code: code, email: params["email"]}

    map_params = fn cs ->
      Params.to_map(cs)
      |> Map.take([:password, :password_confirmation])
      |> Map.put(:password_reset_code, nil)
    end

    with %Ecto.Changeset{valid?: true} = cs <- reset_password_params(params),
         {:ok, user} <- Accounts.get_user(default_params),
         {:ok, _} <- Accounts.update_admin_password(user, map_params.(cs)) do
      conn
      |> put_flash(:success, "Password changed successfully!")
      |> redirect(to: Routes.session_path(conn, :new))
    end
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}} = params) do
    case Accounts.authenticate(email, password, :admin) do
      {:ok, user} ->
        conn
        |> Auth.build_session(user)
        |> logged_in_redirect(params)

      {:error, :disabled} ->
        conn
        |> put_flash(:error, "Account disabled")
        |> put_status(200)
        |> render("new.html")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid email/password")
        |> put_status(200)
        |> render("new.html")

      {:error, _, message} ->
        conn
        |> put_flash(:error, message)
        |> put_status(200)
        |> render("new.html")
    end
  end

  def log_out(conn, params), do: delete(conn, params)

  def delete(conn, _) do
    conn
    |> Auth.browser_sign_out()
    |> put_status(302)
    |> redirect(to: Routes.session_path(conn, :logged_out))
  end

  def reset_password(conn, _) do
    render(conn, "reset.html", user: nil, password_reset_code: nil)
  end

  def reset(conn, %{"session" => %{"email" => email}}) do
    case Accounts.reset_admin_password(%{email: email}) do
      :ok -> put_flash(conn, :success, "Email sent")
      :not_found -> put_flash(conn, :error, "Invalid email")
      :disabled -> put_flash(conn, :error, "Account disabled")
      :not_updated -> put_flash(conn, :error, "Something went wrong")
    end
    |> render("reset.html", password_reset_code: nil)
  end

  def logged_out(conn, params) do
    if Auth.current_user(conn) do
      logged_in_redirect(conn, params)
    else
      render(conn, "logged_out.html")
    end
  end

  def already_authenticated(%{assigns: %{version: version}} = conn, _) do
    conn
    |> put_status(302)
    |> redirect(to: get_api_matches_url(version))
  end

  def auth_error(conn, {_type, _reason}, _opts) do
    conn
    |> put_flash(:error, "Authentication Required")
    |> put_status(302)
    |> redirect(to: Routes.session_path(conn, :logged_out, redirect_url: conn.request_path))
  end

  defp logged_in_redirect(conn, %{"redirect_url" => redirect_url})
       when not is_empty(redirect_url),
       do: redirect(conn, to: redirect_url)

  defp logged_in_redirect(conn, _params),
    do: redirect(conn, to: Routes.matches_path(conn, :index))
end
