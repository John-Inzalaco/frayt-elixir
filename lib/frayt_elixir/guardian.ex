defmodule FraytElixir.Guardian do
  use Guardian, otp_app: :frayt_elixir
  alias FraytElixir.Accounts

  def subject_for_token(%{id: id}, _claims) do
    # You can use any value for the subject of your token but
    # it should be useful in retrieving the resource later, see
    # how it being used on `resource_from_claims/1` function.
    # A unique `id` is a good subject, a non-unique email address
    # is a poor subject.
    sub = to_string(id)
    {:ok, sub}
  end

  # def subject_for_token(_, _) do
  #   {:error, :reason_for_error}
  # end

  def resource_from_claims(%{"sub" => id, "aud" => "frayt_api"}) do
    case Accounts.get_api_account(id) do
      {:error, _} -> {:error, :invalid_token}
      {:ok, api_account} -> {:ok, api_account}
    end
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      {:error, _} -> {:error, :invalid_token}
      {:ok, user} -> {:ok, user}
    end
  end

  # def resource_from_claims(_claims) do
  #   {:error, :reason_for_error}
  # end

  def revoke_all(resource, claims \\ %{}) do
    with {:ok, sub} <- subject_for_token(resource, claims) do
      Guardian.DB.revoke_all(sub)
    end
  end

  def after_encode_and_sign(resource, claims, token, _options) do
    with {:ok, _} <- Guardian.DB.after_encode_and_sign(resource, claims["typ"], claims, token) do
      {:ok, token}
    end
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    with {:ok, _, _} <- Guardian.DB.on_refresh({old_token, old_claims}, {new_token, new_claims}) do
      {:ok, {old_token, old_claims}, {new_token, new_claims}}
    end
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end
end
