defmodule FraytElixir.Accounts.User do
  use FraytElixir.Schema

  import FraytElixir.Sanitizers

  alias FraytElixir.Accounts.{Shipper, AdminUser, UserAgreement}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Rating.NpsScore

  @add_hash Application.compile_env(:frayt_elixir, :hash_password, &Argon2.add_hash/2)

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)
    field(:password_reset_code, :string)
    field(:auth_via_bubble, :boolean)
    field(:old_user_id, :string)

    has_many(:agreements, UserAgreement)
    has_one(:shipper, Shipper)
    has_one(:driver, Driver)
    has_one(:admin, AdminUser)
    has_one(:nps_score, NpsScore)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_reset_code, :auth_via_bubble])
    |> cast_assoc(:agreements)
    |> validate_email()
    |> validate_required([:email, :password])
    |> put_hashed_password()
  end

  @doc false
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password_reset_code])
    |> validate_email()
    |> validate_required([:email])
  end

  def set_initial_password_changeset(user, attrs) do
    user
    |> password_changeset(attrs)
    |> validate_hashed_password_is_empty()
    |> put_hashed_password()
  end

  def forgot_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password_reset_code, :auth_via_bubble])
    |> validate_required([:password_reset_code])
  end

  def change_password_changeset(user, attrs) do
    user
    |> password_changeset(attrs)
    |> put_hashed_password()
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation, :password_reset_code])
    |> validate_length(:password, min: 8, message: "must contain at least #{8} characters")
    |> validate_format(:password, ~r/[A-Za-z]/, message: "must contain a letter")
    |> validate_format(:password, ~r/[0-9]/, message: "must contain a number")
    |> validate_format(:password, ~r/[\p{P}\p{S}]/, message: "must contain a special character")
    |> validate_confirmation(:password, message: "must match")
  end

  defp put_hashed_password(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, hash_password(password))
  end

  defp put_hashed_password(changeset), do: changeset

  def hash_password(password) do
    @add_hash.(password, hash_key: :hashed_password)
  end

  defp validate_hashed_password_is_empty(changeset) do
    validate_change(changeset, :password, :password_not_set, fn _field, _value ->
      case get_field(changeset, :hashed_password) do
        nil -> []
        _ -> [password: {"has already been set", [validation: :password_not_set]}]
      end
    end)
  end

  defp validate_email(changeset) do
    changeset
    |> trim_string(:email)
    |> validate_email_format(:email)
    |> unique_constraint(:email, message: "has already been taken.")
  end
end
