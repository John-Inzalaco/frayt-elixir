defmodule FraytElixir.Accounts.AdminUser do
  use FraytElixir.Schema
  alias FraytElixir.Accounts.{User, AdminRole}
  alias FraytElixir.Notifications.NotificationBatch
  alias FraytElixir.Type.PhoneNumber

  import Ecto.Query, only: [from: 2]
  import FraytElixir.Guards

  schema "admin_users" do
    field :name, :string
    field :role, AdminRole.Type, default: :member
    field :sales_goal, :integer
    field :site_theme, SiteThemeEnum, default: :light
    field :disabled, :boolean, default: false
    field :slack_id, :string
    field :phone_number, PhoneNumber

    belongs_to :user, User
    has_many :notification_batches, NotificationBatch

    timestamps()
  end

  @allowed_field ~w(name role sales_goal disabled site_theme phone_number)a

  @doc false
  def changeset(admin, attrs) do
    admin
    |> cast(attrs, @allowed_field)
    |> validate_required([:name, :role])
    |> validate_required_when(:phone_number, [{:role, :equal_to, :network_operator}],
      message: "can't be blank for network operators"
    )
    |> validate_phone_number(:phone_number)
  end

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(a in query,
        join: u in assoc(a, :user),
        where: ilike(a.name, ^"%#{search_query}%"),
        or_where: ilike(u.email, ^"%#{search_query}%"),
        or_where: ilike(a.phone_number, ^"%#{search_query}%")
      )

  def filter_by_role(query, nil), do: query

  def filter_by_role(query, role) when is_atom(role),
    do: from(a in query, where: a.role == ^role)

  def show_disabled?(query, false),
    do: from(a in query, where: a.disabled != true)

  def show_disabled?(query, _show), do: query

  def user_changeset(admin_user, attrs) do
    admin_user
    |> changeset(attrs)
    |> cast_assoc(:user,
      required: true,
      with: &User.update_changeset/2
    )
  end
end
