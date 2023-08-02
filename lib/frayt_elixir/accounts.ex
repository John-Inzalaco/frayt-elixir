defmodule FraytElixir.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias FraytElixir.Repo

  alias FraytElixir.Accounts.{
    User,
    Location,
    Company,
    AdminUser,
    Shipper,
    Schedule,
    ApiAccount,
    DriverSchedule,
    AgreementDocument,
    UserAgreement,
    ShipperRole,
    DocumentType
  }

  alias FraytElixir.Shipment
  alias Shipment.{Address, Match}
  alias FraytElixir.{Email, Mailer}
  alias FraytElixir.Drivers
  alias Drivers.Driver
  alias FraytElixir.Notifications.{SentNotification, Slack}
  alias FraytElixir.Hubspot
  alias Ecto.Association.NotLoaded
  alias Ecto.Multi

  @check_password Application.compile_env(:frayt_elixir, :check_password, &Argon2.check_pass/3)

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user(%{} = attrs), do: User |> Repo.get_by(attrs) |> user_tuple()
  def get_user(id), do: User |> Repo.get(id) |> user_tuple()
  def get_user!(id), do: User |> Repo.get!(id) |> preload_user()

  def preload_user(user), do: preload_user(user, false)

  def preload_user(user, force?),
    do: Repo.preload(user, [:admin, :shipper, :driver], force: force?)

  defp user_tuple(nil), do: {:error, "no user found"}
  defp user_tuple(user), do: {:ok, preload_user(user)}

  defp company_tuple(nil), do: {:error, "no company found"}
  defp company_tuple(company), do: {:ok, company}

  defp api_account_tuple(nil), do: {:error, "no api_account found"}
  defp api_account_tuple(api_account), do: {:ok, api_account}

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    attrs = normalize_email_attrs(attrs)

    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def normalize_email_attrs(nil), do: nil
  def normalize_email_attrs(%{email: nil} = attrs), do: attrs
  def normalize_email_attrs(attrs) when not is_map_key(attrs, :email), do: attrs

  def normalize_email_attrs(attrs) do
    [local, domain] = String.split(attrs.email, "@", parts: 2)
    normalized_email = local <> "@" <> String.downcase(domain)

    Map.put(attrs, :email, normalized_email)
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    attrs = normalize_email_attrs(attrs)

    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def authenticate(nil, _, _), do: {:error, :invalid_credentials}

  def authenticate(email, password, user_type) do
    email = String.downcase(email)

    with {:ok, user} <- get_user(%{email: email}),
         {:ok, _user} <- check_password(user, password),
         true <- can_access_app?(user, user_type) do
      case user_type do
        :admin -> check_for_disabled_admin(user)
        :shipper -> check_for_disabled_shipper(user)
        _ -> {:ok, user}
      end
    else
      {:error, _, message} -> {:error, :invalid_credentials, message}
      false -> {:error, :invalid_user}
      _ -> {:error, :invalid_credentials}
    end
  end

  defp can_access_app?(user, user_type) do
    case Map.get(user, user_type) do
      nil -> false
      %_{} -> true
    end
  end

  def authenticate_client_secret(client_id, secret) do
    case Repo.get_by(ApiAccount, client_id: client_id, secret: secret) do
      %ApiAccount{} = api_account -> {:ok, api_account}
      nil -> {:error, :invalid_credentials}
    end
  end

  def check_password(_, nil), do: {:error, :invalid_password}

  def check_password(%User{auth_via_bubble: true}, _) do
    {:error, :invalid_credentials,
     "Your password has expired. Use the \"Forgot Password\" flow to login to your account."}
  end

  def check_password(%User{email: email, password_reset_code: code}, password)
      when not is_nil(code) do
    case Repo.get_by(User, email: email, password_reset_code: password) do
      %User{} = user -> {:ok, user}
      _ -> {:error, :invalid_credentials}
    end
  end

  def check_password(user, password) do
    case @check_password.(user, password, hash_key: :hashed_password) do
      {:error, "invalid user-identifier"} -> {:error, :invalid_user_identifier}
      {:error, _} -> {:error, :invalid_password}
      {:ok, user} -> {:ok, user}
    end
  end

  def verify_code(_, nil), do: {:error, :invalid_credentials}

  def verify_code(email, code) do
    case Repo.get_by(User, email: email, password_reset_code: code) do
      %User{} = user ->
        user
        |> User.update_changeset(%{password_reset_code: nil})
        |> Repo.update()

      _ ->
        {:error, :invalid_credentials}
    end
  end

  def set_password_reset_code(user), do: user |> set_password_reset_code(random_string(8))

  def set_password_reset_code(%User{} = user, code) when is_bitstring(code) do
    user
    |> User.forgot_password_changeset(%{
      password_reset_code: code,
      auth_via_bubble: false
    })
    |> Repo.update()
  end

  def set_password_reset_code(_, _), do: {:error, :invalid_user}

  def forgot_password(email) do
    with %User{} = user <- Repo.get_by(User, email: email) do
      {:ok, %User{email: email, password_reset_code: code}} =
        user
        |> User.forgot_password_changeset(%{
          password_reset_code: random_string(8),
          auth_via_bubble: false
        })
        |> Repo.update()

      with %Shipper{first_name: first_name, last_name: last_name} <- get_shipper_by_email(email) do
        Email.shipper_reset_email(%{
          email: email,
          password_reset_code: code,
          first_name: first_name,
          last_name: last_name
        })
        |> Mailer.deliver_later()
      end

      with {:ok, %Driver{first_name: first_name, last_name: last_name}} <-
             Drivers.get_driver_for_user(user) do
        Email.shipper_reset_email(%{
          email: email,
          password_reset_code: code,
          first_name: first_name,
          last_name: last_name
        })
        |> Mailer.deliver_later()
      end
    end
  end

  def reset_password(email, code, password, password_confirmation) do
    case Repo.get_by(User, email: email, password_reset_code: code) do
      %User{} = user ->
        user
        |> User.change_password_changeset(%{
          password_reset_code: nil,
          password: password,
          password_confirmation: password_confirmation
        })
        |> Repo.update()

      _ ->
        {:error, :invalid_credentials}
    end
  end

  alias FraytElixir.PaginationQueryHelpers

  @doc """
  Returns the list of shippers.

  ## Examples

      iex> list_shippers()
      [%Shipper{}, ...]

  """
  def list_shippers, do: Shipper |> Repo.all()

  def list_shippers(
        filters,
        preload \\ [
          :user,
          :address,
          :credit_card,
          sales_rep: [:user],
          location: [company: [sales_rep: [:user]], sales_rep: [:user]]
        ]
      ) do
    query = Map.get(filters, :query)
    company_id = Map.get(filters, :company_id)
    state = Map.get(filters, :state)
    role = Map.get(filters, :role)
    sales_rep_id = Map.get(filters, :sales_rep_id)

    Shipper.new_query()
    |> Shipper.filter_by_query(query)
    |> Shipper.filter_by_company(company_id)
    |> Shipper.filter_by_sales_rep(sales_rep_id)
    |> Shipper.filter_by_state(state)
    |> Shipper.filter_by_role(role)
    |> PaginationQueryHelpers.list_record(filters, preload)
  end

  @type account_shippers_filters :: %{
          optional(:query) => String.t() | nil,
          optional(:role) => ShipperRole.Type.t() | list(ShipperRole.Type.t()) | nil,
          optional(:location_id) => String.t() | nil,
          optional(:state) => String.t() | nil,
          optional(:per_page) => integer(),
          optional(:page) => integer(),
          optional(:order) => :desc | :asc,
          optional(:order_by) => atom()
        }

  @spec list_account_shippers(shipper :: Shipper.t(), filters :: account_shippers_filters()) ::
          {results :: list(Shipper.t()), page_count :: integer()}
  def list_account_shippers(shipper, filters \\ %{}) do
    query = Map.get(filters, :query)
    role = Map.get(filters, :role)
    location_id = Map.get(filters, :location_id)
    state = Map.get(filters, :state)
    shipper = Repo.preload(shipper, :location)

    Shipper.new_query()
    |> Shipper.filter_by_permissions(shipper, location_id)
    |> Shipper.filter_by_query(query)
    |> Shipper.filter_by_role(role)
    |> Shipper.filter_by_state(state)
    |> PaginationQueryHelpers.list_record(filters, [:user, location: [:company]])
  end

  @doc """
  Gets a single shipper.

  Raises `Ecto.NoResultsError` if the Shipper does not exist.

  ## Examples

      iex> get_shipper!(123)
      %Shipper{}

      iex> get_shipper!(456)
      ** (Ecto.NoResultsError)

  """
  def get_shipper!(id),
    do: Repo.get!(Shipper, id) |> Repo.preload([:address, user: [], location: [:company]])

  def get_account_shipper(shipper, shipper_id) do
    from(s in Shipper, where: s.id == ^shipper_id)
    |> Shipper.filter_by_permissions(shipper, nil)
    |> Repo.one()
    |> Repo.preload(user: [], location: [:company])
  end

  def new_shipper?(id), do: Shipper |> Shipper.new_shipper?(id) |> Repo.one()

  @doc """
  Creates a shipper.

  ## Examples

      iex> create_shipper(%{field: value})
      {:ok, %Shipper{}}

      iex> create_shipper(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_shipper(%{email: email, password: password} = attrs) do
    {agreement_attrs, _} = build_user_agreement_attrs(:shipper, Map.get(attrs, :agreements, []))

    shipper_attrs =
      attrs
      |> Map.put(:user, %{
        email: email,
        password: password,
        agreements: agreement_attrs
      })

    case %Shipper{}
         |> Shipper.changeset(shipper_attrs)
         |> Ecto.Changeset.cast_assoc(:user, required: true)
         |> Ecto.Changeset.cast_assoc(:address)
         |> Repo.insert() do
      {:ok, shipper} ->
        Task.start_link(fn -> sync_shipper_with_hubspot(shipper, attrs) end)

        {:ok, shipper}

      errors ->
        errors
    end
  end

  def create_shipper(%{user: %{email: _}} = attrs) do
    attrs = set_password_reset(attrs)

    with {:ok, shipper} <- insert_invited_shipper(attrs) do
      send_shipper_invite(shipper)
      {:ok, shipper}
    end
  end

  def create_shipper(attrs) do
    %Shipper{}
    |> Shipper.changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:user, required: true)
    |> Repo.insert()
  end

  def sync_shipper_with_hubspot(shipper, attrs) do
    %Shipper{commercial: commercial} = shipper

    if commercial do
      case Hubspot.sync_shipper(shipper, attrs) do
        {:ok, shipper} ->
          Slack.send_shipper_message(shipper)

        {:error, error} ->
          Slack.send_shipper_message(shipper, hubspot_error: error)
      end
    end
  end

  defp insert_invited_shipper(attrs),
    do:
      %Shipper{}
      |> Shipper.changeset(attrs)
      |> Ecto.Changeset.cast_assoc(:user,
        required: true,
        with: &FraytElixir.Accounts.User.update_changeset/2
      )
      |> Ecto.Changeset.cast_assoc(:address,
        with: &FraytElixir.Shipment.Address.invite_shipper_changeset/2
      )
      |> Repo.insert()

  def create_account_shipper(current_shipper, attrs) do
    sales_rep_id =
      case Map.get(attrs, :location_id) do
        nil ->
          nil

        location_id ->
          location_id
          |> get_location!()
          |> Map.get(:sales_rep_id)
      end

    attrs =
      set_password_reset(attrs)
      |> Map.put(:state, :approved)
      |> Map.put(:sales_rep_id, sales_rep_id)

    with {:ok, shipper} <- insert_account_shipper(attrs, current_shipper) do
      send_shipper_invite(shipper)
      {:ok, shipper}
    end
  end

  defp insert_account_shipper(attrs, current_shipper),
    do:
      %Shipper{}
      |> Shipper.account_shipper_changeset(attrs, current_shipper)
      |> Repo.insert()

  defp set_password_reset(attrs),
    do:
      Map.put(attrs, :user, %{
        email: get_in(attrs, [:user, :email]),
        password_reset_code: random_string(8)
      })

  defp send_shipper_invite(%Shipper{
         first_name: first_name,
         last_name: last_name,
         user: %User{email: email, password_reset_code: password_reset_code}
       }),
       do:
         %{
           email: email,
           password_reset_code: password_reset_code,
           first_name: first_name,
           last_name: last_name
         }
         |> Email.shipper_invite_email()
         |> Mailer.deliver_later()

  def get_shipper_by_email(nil) do
    nil
  end

  def get_shipper_by_email(email) do
    email =
      email
      |> String.trim()
      |> String.downcase()

    from(s in Shipper,
      join: u in User,
      on: s.user_id == u.id,
      where: u.email == ^email
    )
    |> Repo.one()
  end

  @doc """
  Updates a shipper.

  ## Examples

      iex> update_shipper(shipper, %{field: new_value})
      {:ok, %Shipper{}}

      iex> update_shipper(shipper, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_shipper(nil, %{}), do: {:ok, nil}

  def update_shipper(%Shipper{} = shipper, %{user: %{email: _}} = attrs) do
    shipper
    |> Shipper.changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:user,
      required: true,
      with: &FraytElixir.Accounts.User.update_changeset/2
    )
    |> Ecto.Changeset.cast_assoc(:address)
    |> Repo.update()
  end

  def update_shipper(%Shipper{} = shipper, attrs) do
    shipper
    |> Shipper.changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:address)
    |> Ecto.Changeset.cast_assoc(:user,
      required: true,
      with: &FraytElixir.Accounts.User.update_changeset/2
    )
    |> Repo.update()
  end

  def update_account_shipper(current_shipper, shipper, attrs),
    do:
      shipper
      |> Shipper.account_shipper_changeset(attrs, current_shipper)
      |> Repo.update()

  def update_shipper_profile(%Shipper{} = shipper, attrs) do
    shipper
    |> Shipper.update_profile_changeset(attrs)
    |> Repo.update()
  end

  def update_shipper_stripe(%Shipper{} = shipper, attrs) do
    shipper
    |> Shipper.update_stripe_changeset(attrs)
    |> Repo.update()
  end

  def change_password(%User{} = user, %{"new" => new, "old" => old}) do
    case @check_password.(user, old, hash_key: :hashed_password) do
      {:ok, user} ->
        user
        |> User.change_password_changeset(%{password: new, password_confirmation: new})
        |> Repo.update()

      {:error, _msg} ->
        {:error, :invalid_credentials}
    end
  end

  def change_password(%User{} = user, attrs) do
    user
    |> User.change_password_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a shipper.

  ## Examples

      iex> delete_shipper(shipper)
      {:ok, %Shipper{}}

      iex> delete_shipper(shipper)
      {:error, %Ecto.Changeset{}}

  """
  def delete_shipper(%Shipper{} = shipper) do
    Repo.delete(shipper)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking shipper changes.

  ## Examples

      iex> change_shipper(shipper)
      %Ecto.Changeset{source: %Shipper{}}

  """
  def change_shipper(%Shipper{} = shipper) do
    Shipper.changeset(shipper, %{})
  end

  def get_schedule(id), do: Repo.get(Schedule, id)

  def create_schedule(attrs) do
    %Schedule{}
    |> Schedule.changeset(attrs)
    |> Repo.insert()
  end

  def update_schedule(%Schedule{} = schedule, attrs) do
    schedule
    |> Schedule.changeset(attrs)
    |> Repo.update()
  end

  def get_schedule_for_location(%Location{id: location_id}),
    do: Repo.get_by(Schedule, location_id: location_id) |> Repo.preload(:drivers)

  def get_schedule_for_location(location_id),
    do: Repo.get_by(Schedule, location_id: location_id) |> Repo.preload(:drivers)

  def list_unaccepted_schedules_for_driver(%Driver{id: driver_id}) do
    from(
      s in Schedule,
      join: sent in SentNotification,
      on: sent.driver_id == ^driver_id,
      full_join: ds in DriverSchedule,
      on: ds.schedule_id == s.id and ds.driver_id == ^driver_id,
      where: s.id != sent.schedule_id and is_nil(ds),
      distinct: s.id
    )
    |> Repo.all()
  end

  def add_driver_to_schedule(%{schedule_id: schedule_id, driver_id: driver_id} = attrs) do
    case get_drivers_schedule(schedule_id, driver_id) do
      nil ->
        %DriverSchedule{}
        |> DriverSchedule.changeset(attrs)
        |> Repo.insert()

      _ ->
        {:error, :already_in_fleet}
    end
  end

  def remove_driver_from_schedule(schedule_id, driver_id) do
    case get_drivers_schedule(schedule_id, driver_id) do
      %DriverSchedule{} = schedule -> Repo.delete(schedule)
      _ -> {:error, :not_in_fleet}
    end
  end

  defp get_drivers_schedule(schedule_id, driver_id) do
    from(ds in DriverSchedule,
      where: ds.schedule_id == ^schedule_id and ds.driver_id == ^driver_id
    )
    |> Repo.one()
  end

  def get_location!(id),
    do: Repo.get!(Location, id) |> Repo.preload([:shippers, :schedule, :address])

  def get_location_revenue(id) do
    Location.calculate_revenue(id)
  end

  def list_locations(%{query: query, parent_id: company_id} = args),
    do:
      Location
      |> Location.filter_by_company(company_id)
      |> Location.filter_by_query(query)
      |> PaginationQueryHelpers.list_record(args, [:shippers])

  def list_company_locations_with_schedules(company_id) do
    from(l in Location,
      join: s in assoc(l, :schedule),
      where: l.company_id == ^company_id and not is_nil(s),
      distinct: l.id
    )
    |> Repo.all()
  end

  def create_location(attrs) do
    %Location{}
    |> Location.changeset(attrs)
    |> Repo.insert()
  end

  def update_location(%Location{} = location, attrs) do
    location
    |> Location.changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:address,
      required: true,
      with: &Address.admin_geocoding_changeset/2
    )
    |> Repo.update()
  end

  def delete_location(%Location{} = location) do
    Repo.delete(location)
  end

  def get_company!(id), do: Repo.get!(Company, id)

  def get_company(id), do: Repo.get(Company, id) |> company_tuple()

  def get_company_id_from_shipper(nil), do: nil

  def get_company_id_from_shipper(shipper_id),
    do:
      Repo.one(
        from(c in Company,
          left_join: l in assoc(c, :locations),
          left_join: s in assoc(l, :shippers),
          where: s.id == ^shipper_id,
          select: c.id
        )
      )

  def company_has_account_billing?(nil), do: nil
  def company_has_account_billing?(id), do: Repo.get(Company, id).account_billing_enabled

  def get_company_invoice_period(nil), do: nil
  def get_company_invoice_period(id), do: Repo.get(Company, id).invoice_period

  def get_company_sales_rep_id(nil), do: nil
  def get_company_sales_rep_id(id), do: Repo.get(Company, id).sales_rep_id

  def get_api_account!(id), do: Repo.get!(ApiAccount, id)

  def get_api_account(id), do: Repo.get(ApiAccount, id) |> api_account_tuple()

  def get_api_account_by_client_id(client_id), do: Repo.get_by(ApiAccount, client_id: client_id)

  def delete_api_account(%ApiAccount{} = api_account), do: Repo.delete(api_account)

  def create_api_account(company),
    do:
      %ApiAccount{}
      |> ApiAccount.new_account_changeset(company)
      |> Repo.insert()

  def list_companies_with_schedules do
    from(c in Company,
      join: l in assoc(c, :locations),
      join: s in assoc(l, :schedule),
      where: not is_nil(s),
      distinct: c.id
    )
    |> Repo.all()
  end

  def list_companies do
    Repo.all(Company)
  end

  @type companies_filters :: %{
          optional(:query) => String.t() | nil,
          optional(:sales_rep_id) => String.t() | nil,
          optional(:enterprise_only) => boolean() | nil
        }
  @spec list_companies(filters :: companies_filters()) ::
          {results :: list(Company.t()), page_count :: integer()}

  def list_companies(%{enterprise_only: enterprise_only}),
    do:
      Company
      |> Company.filter_by_enterprise_only(enterprise_only)
      |> Repo.all()

  def list_companies(filters) do
    query = Map.get(filters, :query)
    sales_rep_id = Map.get(filters, :sales_rep_id)

    Company
    |> Company.filter_by_query(query)
    |> Company.filter_by_sales_rep(sales_rep_id)
    |> PaginationQueryHelpers.list_record(
      filters,
      locations: [:address, sales_rep: [:user], shippers: [:user]],
      sales_rep: [:user]
    )
  end

  def create_company(
        %{
          company: company,
          location: _location,
          address: _address,
          shippers: _shippers
        } = attrs
      ) do
    case %Company{}
         |> Company.create_changeset(company)
         |> Repo.insert() do
      {:ok, company} ->
        attrs
        |> Map.put(:company, company.id)
        |> add_location_with_shippers()

      response ->
        response
    end
  end

  def create_company(attrs) do
    %Company{}
    |> Company.create_changeset(attrs)
    |> Repo.insert()
  end

  def add_location_with_shippers(%{
        company: company_id,
        location: location,
        address: address,
        shippers: %{users: shippers}
      }) do
    {:ok, address} = Shipment.create_address_for_location(address)

    location =
      location
      |> Map.put(:company_id, company_id)
      |> Map.put(:address_id, address.id)

    {:ok, location} =
      %Location{}
      |> Location.changeset(location)
      |> Repo.insert()

    shippers
    |> Enum.each(
      &update_shipper(&1, %{location_id: location.id, company: get_company!(company_id).name})
    )
  end

  def update_company_locations(
        %{company: _company, location: _location, address: _address, shippers: _shippers} = attrs
      ) do
    add_location_with_shippers(attrs)
  end

  def update_company(%Company{} = company, attrs) do
    company
    |> Company.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_company(%Company{} = company) do
    Repo.delete(company)
  end

  def list_sales_reps,
    do:
      Repo.all(from(a in AdminUser, where: a.role == "sales_rep" and not a.disabled))
      |> Repo.preload(:user)

  def list_admins,
    do: AdminUser |> order_by(asc: :inserted_at) |> Repo.all() |> Repo.preload(:user)

  def list_admins(args),
    do:
      AdminUser
      |> AdminUser.filter_by_query(Map.get(args, :query))
      |> AdminUser.filter_by_role(Map.get(args, :role))
      |> AdminUser.show_disabled?(Map.get(args, :show_disabled, false))
      |> PaginationQueryHelpers.list_record(args, [:user])

  def get_admin!(id), do: Repo.get!(AdminUser, id) |> Repo.preload(:user)

  def get_admin(id), do: Repo.get(AdminUser, id) |> Repo.preload(:user)

  def get_admin_by_email(nil), do: nil

  def get_admin_by_email(email) do
    email =
      email
      |> String.trim()
      |> String.downcase()

    from(a in AdminUser,
      join: u in User,
      on: a.user_id == u.id,
      where: u.email == ^email
    )
    |> Repo.one()
  end

  def invite_admin(%{user: user_attrs} = attrs) do
    attrs = %{attrs | user: Map.put(user_attrs, :password_reset_code, random_string(8))}
    admin_changeset = AdminUser.user_changeset(%AdminUser{}, attrs)

    case Repo.insert(admin_changeset) do
      {:ok, admin_user} ->
        %AdminUser{
          name: name,
          user: %User{
            email: email,
            password_reset_code: password_reset_code
          }
        } = admin_user

        %{
          email: email,
          password_reset_code: password_reset_code,
          name: name
        }
        |> Email.invitation_email()
        |> Mailer.deliver_later()

        {:ok, admin_user}

      errors ->
        errors
    end
  end

  def check_for_disabled_admin(%User{admin: nil}), do: {:error, :not_found}

  def check_for_disabled_admin(%User{admin: %AdminUser{disabled: disabled?}} = user) do
    case disabled? do
      true -> {:error, :disabled}
      _ -> clear_password_reset(user)
    end
  end

  def check_for_disabled_shipper(%User{shipper: %Shipper{state: :disabled}}),
    do: {:error, :disabled}

  def check_for_disabled_shipper(user), do: {:ok, user}

  def disable_admin_account(admin_email) do
    case get_user(%{email: admin_email}) do
      {:ok, %User{admin: %AdminUser{} = admin}} ->
        admin
        |> AdminUser.changeset(%{disabled: true})
        |> Repo.update()

      {:error, _} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :not_an_admin}
    end
  end

  def enable_admin_account(admin_email) do
    case get_user(%{email: admin_email}) do
      {:ok, %User{admin: %AdminUser{disabled: true} = admin}} ->
        changeset = AdminUser.changeset(admin, %{disabled: false})

        case Repo.update(changeset) do
          {:ok, %AdminUser{disabled: false}} -> {:ok, :enabled}
          {:error, _} -> {:error, :not_enabled}
        end

      {:ok, %User{admin: %AdminUser{}}} ->
        {:error, :not_disabled}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def reset_admin_password(%{email: email}) do
    with {:ok, %User{} = user} <- get_user(%{email: email}),
         {:ok, _user} <- check_for_disabled_admin(user) do
      changeset = User.update_changeset(user, %{password_reset_code: random_string(8)})

      case Repo.update(changeset) do
        {:ok, %User{} = user} ->
          user
          |> Map.take([:email, :password_reset_code])
          |> Email.admin_reset_email()
          |> Mailer.deliver_later()

          :ok

        {:error, _changeset} ->
          :not_updated
      end
    else
      {:error, :disabled} -> :disabled
      _ -> :not_found
    end
  end

  def clear_password_reset(%User{password_reset_code: nil} = user), do: {:ok, user}

  def clear_password_reset(user) do
    user
    |> User.update_changeset(%{password_reset_code: nil})
    |> Repo.update()
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
    |> String.upcase()
  end

  def update_admin_password(%AdminUser{user: %User{} = admin_user}, %{
        new_password: new_password,
        old_password: old_password
      }) do
    clear_password_reset(admin_user)
    |> elem(1)
    |> change_password(%{"old" => old_password, "new" => new_password})
  end

  def update_admin_password(%User{} = user, params),
    do: change_password(user, params)

  def update_admin(%AdminUser{} = admin, attrs),
    do:
      admin
      |> AdminUser.user_changeset(attrs)
      |> Repo.update()

  def remove_admin(%AdminUser{} = admin) do
    Repo.delete(admin)
    Repo.delete(admin.user)
  end

  def get_shipper_email(%Shipper{user: %NotLoaded{}} = shipper),
    do: shipper |> Repo.preload(:user) |> get_shipper_email()

  def get_shipper_email(%Shipper{user: %User{email: email}}), do: email
  def get_shipper_email(_), do: nil

  def get_match_company(%Match{
        shipper: %Shipper{location: %Location{company: %Company{} = company}}
      }),
      do: company

  def get_match_company(%Match{shipper: %NotLoaded{}} = match),
    do: match |> Repo.preload(shipper: [location: [:company]]) |> get_match_company()

  def get_match_company(%Match{shipper: %Shipper{location: %NotLoaded{}}} = match),
    do: match |> Repo.preload(shipper: [location: [:company]]) |> get_match_company()

  def get_match_company(
        %Match{shipper: %Shipper{location: %Location{company: %NotLoaded{}}}} = match
      ),
      do: match |> Repo.preload(shipper: [location: [:company]]) |> get_match_company()

  def get_match_company(_), do: nil

  def toggle_admin_theme(%AdminUser{site_theme: site_theme} = admin) do
    new_theme =
      case site_theme do
        :dark -> :light
        _ -> :dark
      end

    admin
    |> AdminUser.changeset(%{site_theme: new_theme})
    |> Repo.update()
  end

  def list_agreement_documents(args),
    do:
      AgreementDocument
      |> AgreementDocument.filter_by_query(Map.get(args, :query, ""))
      |> PaginationQueryHelpers.list_record(args, [
        :parent_document,
        :support_documents
      ])

  def list_pending_agreements(%Shipper{user: user}), do: list_pending_agreements(user, :shipper)
  def list_pending_agreements(%Driver{user: user}), do: list_pending_agreements(user, :driver)
  def list_pending_agreements(type) when is_atom(type), do: list_pending_agreements(%User{}, type)

  def list_pending_agreements(%User{id: user_id}, user_type) do
    preload_support_docs_query =
      from(sd in AgreementDocument, where: sd.state == :published and ^user_type in sd.user_types)

    filter_docs(user_type, user_id)
    |> where([d], is_nil(d.parent_document_id))
    |> preload([], support_documents: ^preload_support_docs_query)
    |> Repo.all()
  end

  defp filter_docs(user_type, user_id, filter_support \\ true) do
    from(d in AgreementDocument, where: ^user_type in d.user_types and d.state == :published)
    |> filter_user_agreements(user_type, user_id, filter_support)
  end

  defp filter_user_agreements(query, _, nil, _), do: query

  defp filter_user_agreements(query, user_type, user_id, filter_support) do
    query =
      query
      |> join(:left, [d], a in UserAgreement, on: a.document_id == d.id and a.user_id == ^user_id)

    if filter_support do
      query
      |> filter_support_agreements(user_type, user_id)
      |> where([d, a, sd], is_nil(a) or a.updated_at < d.updated_at or not is_nil(sd))
    else
      query
      |> where([d, a], is_nil(a) or a.updated_at < d.updated_at)
    end
  end

  defp filter_support_agreements(query, user_type, user_id) do
    support_docs_query =
      filter_docs(user_type, user_id, false)
      |> where([d], not is_nil(d.parent_document_id))
      |> group_by([d], d.parent_document_id)
      |> select([d], %{parent_document_id: d.parent_document_id, count: count(d.id)})

    query
    |> join(:left, [d], sd in subquery(support_docs_query), on: d.id == sd.parent_document_id)
  end

  def get_agreement_document(nil), do: {:error, :not_found}

  def get_agreement_document(id) do
    case Repo.get(AgreementDocument, id) do
      nil -> {:error, :not_found}
      %AgreementDocument{} = doc -> {:ok, doc |> Repo.preload(:support_documents)}
    end
  rescue
    Ecto.Query.CastError -> {:error, :not_found}
  end

  def delete_agreement_document(%AgreementDocument{} = document) do
    Repo.delete(document)
  end

  def accept_agreements(user, attrs) do
    {attrs, existing} = build_user_agreement_attrs(user, attrs)

    with {:ok, results} <-
           attrs
           |> Enum.reduce(Multi.new(), fn agreement, multi ->
             Multi.insert_or_update(
               multi,
               {:agreement, agreement.document_id},
               UserAgreement.changeset(
                 Enum.find(existing, %UserAgreement{}, &(&1.id == Map.get(agreement, :id))),
                 agreement
               )
             )
           end)
           |> Repo.transaction() do
      {:ok, results |> Enum.map(fn {_key, agreement} -> agreement end)}
    end
  end

  def build_user_agreement_attrs(user_type, attrs \\ []) do
    documents = list_pending_agreements(user_type)

    existing_agreements =
      case user_type do
        %{user: user} -> user |> Repo.preload(:agreements) |> Map.get(:agreements)
        _ -> []
      end

    attrs =
      documents
      |> Enum.flat_map(fn document ->
        default = %{
          agreed: false,
          document_id: document.id,
          updated_at: DateTime.utc_now()
        }

        default =
          case user_type do
            %{user: user} -> default |> Map.put(:user_id, user.id)
            _ -> default
          end

        agreement =
          case Enum.find(attrs, &(&1.document_id == document.id)) do
            nil ->
              default

            agreement ->
              default
              |> Map.merge(agreement)
              |> Map.put(:id, get_agreement_id(existing_agreements, document.id))
          end

        case agreement do
          %{agreed: true} ->
            [agreement] ++
              Enum.map(
                document.support_documents,
                &%{
                  agreement
                  | document_id: &1.id,
                    id: get_agreement_id(existing_agreements, &1.id)
                }
              )

          _ ->
            [agreement]
        end
      end)

    {attrs, existing_agreements}
  end

  defp get_agreement_id(agreements, document_id),
    do: Enum.find_value(agreements, &if(&1.document_id == document_id, do: &1.id))

  def update_company_metrics do
    sub_query =
      from(company in Company,
        join: location in subquery(Company.location_revenue_query()),
        on: location.company_id == company.id,
        group_by: company.id,
        select: %{
          company
          | revenue:
              fragment(
                "cast(coalesce(?, 0) as bigint) / coalesce(NULLIF(cast(? / coalesce(NULLIF(?, 0), 1) as bigint), 0), 1)",
                sum(location.revenue),
                count(location),
                count(location, :distinct)
              ),
            match_count:
              fragment(
                "cast(coalesce(?, 0) as bigint) / coalesce(NULLIF(cast(? / coalesce(NULLIF(?, 0), 1) as bigint), 0), 1)",
                sum(location.match_count),
                count(location),
                count(location, :distinct)
              ),
            location_count:
              fragment("cast(coalesce(?, 0) as bigint)", count(location, :distinct)),
            shipper_count:
              fragment(
                "cast(coalesce(?, 0) as bigint) / coalesce(NULLIF(cast(? / coalesce(NULLIF(?, 0), 1) as bigint), 0), 1)",
                sum(location.shipper_count),
                count(location),
                count(location, :distinct)
              )
        }
      )

    from(c in Company,
      join: company in subquery(sub_query),
      on: company.id == c.id,
      update: [
        set: [
          match_count: company.match_count,
          revenue: company.revenue,
          location_count: company.location_count,
          shipper_count: company.shipper_count
        ]
      ]
    )
    |> Repo.update_all([], timeout: 3 * 60_000)
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  def get_company_by_api_key(api_key) do
    Company
    |> where([c], c.api_key == ^api_key)
    |> Repo.one()
  end
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Accounts.Company do
  alias FraytElixir.{Repo, Accounts, PaginationQueryHelpers}
  alias Accounts.Company

  def display_record(c) do
    text =
      if c.is_enterprise do
        "<i class='fa fa-star'></i> "
      else
        ""
      end

    {:safe, text <> "#{c.name} #{c.email && "(#{c.email})"}"}
  end

  def list_records(_record, filters) do
    filters =
      Map.merge(
        %{
          per_page: 4,
          order_by: :name,
          order: :asc
        },
        filters
      )

    query = Map.get(filters, :query)

    Company
    |> Company.filter_by_query(query)
    |> PaginationQueryHelpers.list_record(filters)
  end

  def get_record(%{id: id}), do: Repo.get(Company, id)
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Accounts.Shipper do
  alias FraytElixir.{Repo, Accounts}
  alias Accounts.Shipper
  def display_record(s), do: "#{s.first_name} #{s.last_name} (#{s.user.email})"

  def list_records(_record, filters),
    do:
      %{
        per_page: 4,
        order_by: :first_name,
        order: :asc
      }
      |> Map.merge(filters)
      |> Accounts.list_shippers([:user])

  def get_record(%{id: id}), do: Repo.get(Shipper, id) |> Repo.preload(:user)
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Accounts.AdminUser do
  alias FraytElixir.Accounts
  def display_record(a), do: "#{a.name} (#{a.user.email})"

  def list_records(_record, filters),
    do:
      %{
        per_page: 4,
        order_by: :name,
        order: :asc
      }
      |> Map.merge(filters)
      |> Accounts.list_admins()

  def get_record(%{id: id}), do: Accounts.get_admin(id)
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Accounts.AgreementDocument do
  alias FraytElixir.{Repo, Accounts}
  alias Accounts.{AgreementDocument, DocumentType, UserType}

  def display_record(ad),
    do: "#{ad.title} (#{DocumentType.name(ad.type)} for #{UserType.name(ad.user_types)})"

  def list_records(_record, filters),
    do:
      %{
        per_page: 4,
        order_by: :title,
        order: :asc
      }
      |> Map.merge(filters)
      |> Accounts.list_agreement_documents()

  def get_record(%{id: id}), do: Repo.get(AgreementDocument, id)
end
