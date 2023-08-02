defmodule FraytElixirWeb.API.Internal.ShipperController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixirWeb.ChangesetParams
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.Shipper

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_shipper: 2,
      maybe_authorize_shipper_for_shipper: 2,
      maybe_authorize_shipper: 2
    ]

  import FraytElixir.MapConverter
  alias FraytElixirWeb.SessionView

  plug :authorize_shipper when action in [:update, :show, :index]
  plug :maybe_authorize_shipper_for_shipper when action in [:update]
  plug :maybe_authorize_shipper when action in [:create]

  action_fallback FraytElixirWeb.FallbackController

  defparams(
    account_shipper_params(%{
      first_name: :string,
      last_name: :string,
      role: :string,
      location_id: :string,
      disabled: :boolean,
      phone: :string,
      user: %{
        email: :string
      }
    })
  )

  defparams(
    create_shipper_params(%{
      first_name!: :string,
      last_name!: :string,
      email!: :string,
      phone!: :string,
      password!: :string,
      company: :string,
      one_signal_id: :string,
      address: %{
        address: :string,
        city: :string,
        state: :string,
        zip: :string
      },
      agreements: [
        %{
          document_id!: :string,
          agreed!: :boolean
        }
      ],
      commercial!: :boolean,
      referrer: :string,
      start_shipping: :string,
      monthly_shipments: :string,
      team_size: :string,
      job_title: :string,
      texting: :boolean,
      api_integration: :boolean,
      schedule_demo: :boolean
    })
  )

  def create(%{assigns: %{current_shipper: %Shipper{} = current_shipper}} = conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- account_shipper_params(params) do
      attrs = Params.to_map(changeset)

      with {:ok, shipper} <-
             Accounts.create_account_shipper(current_shipper, attrs) do
        render(conn, "show.json", shipper: shipper)
      end
    end
  end

  def create(conn, shipper_params) do
    with %Ecto.Changeset{valid?: true} = changeset <- create_shipper_params(shipper_params),
         shipper_attrs <-
           Params.to_map(changeset),
         {:ok, %Shipper{} = shipper} <-
           Accounts.create_shipper(shipper_attrs),
         {:ok, token, _claims} <- FraytElixir.Guardian.encode_and_sign(%{id: shipper.user_id}) do
      conn
      |> put_status(:created)
      |> put_view(SessionView)
      |> render("authenticate_shipper.json", shipper: shipper, token: token)
    end
  end

  defparams(
    register_shipper_params(%{
      email!: :string,
      first_name!: :string,
      last_name!: :string,
      phone!: :string,
      company: :string,
      commercial!: :boolean
    })
  )

  def register(conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- register_shipper_params(params) do
      attrs = Params.to_map(changeset)

      attrs =
        attrs
        |> Map.put(:user, %{email: attrs[:email]})
        |> Map.delete(:email)

      with {:ok, %Shipper{} = shipper} <- Accounts.create_shipper(attrs) do
        conn
        |> put_status(:created)
        |> render("show_personal.json", shipper: shipper)
      end
    end
  end

  def show(%{assigns: %{shipper: shipper}} = conn, _) do
    render(conn, "show.json", shipper: shipper)
  end

  def show(%{assigns: %{current_shipper: shipper}} = conn, _) do
    render(conn, "show_personal.json", shipper: shipper)
  end

  def update(
        %{
          assigns: %{
            shipper: shipper,
            current_shipper: %{id: current_shipper_id} = current_shipper
          }
        } = conn,
        %{"id" => shipper_id} = params
      )
      when current_shipper_id !== shipper_id do
    with %Shipper{} <- shipper,
         {:ok, attrs} <-
           account_shipper_params(params) |> ChangesetParams.get_data(),
         {:ok, shipper} <- Accounts.update_account_shipper(current_shipper, shipper, attrs) do
      render(conn, "show.json", shipper: shipper)
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  defparams(
    update_shipper_params(
      first_name: :string,
      last_name: :string,
      email: :string,
      phone: :string,
      company: :string,
      address: %{
        address: :string,
        city: :string,
        state: :string,
        zip: :string
      }
    )
  )

  def update(%{assigns: %{current_shipper: shipper}} = conn, %{"one_signal_id" => one_signal_id}) do
    with {:ok, %Shipper{} = shipper} <-
           Accounts.update_shipper(shipper, %{one_signal_id: one_signal_id}) do
      render(conn, "show_personal.json", shipper: shipper)
    end
  end

  def update(%{assigns: %{current_shipper: shipper}} = conn, params) do
    with {:ok, attrs} <-
           update_shipper_params(params) |> ChangesetParams.get_data(),
         {:ok, %Shipper{} = shipper} <- Accounts.update_shipper_profile(shipper, attrs) do
      render(conn, "show_personal.json", shipper: shipper)
    end
  end

  defparams(
    index_params(%{
      role: :string,
      location_id: :string,
      query: :string,
      disabled: :boolean,
      order_by: :string,
      order: [field: :string, default: "asc"],
      per_page: [field: :integer, default: 10],
      page: [field: :integer, default: 0]
    })
  )

  def index(%{assigns: %{current_shipper: shipper}} = conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- index_params(params) do
      filters =
        changeset
        |> Params.to_map()
        |> convert_key_value_to!(:atom, [:order, :order_by, :role])

      {shippers, page_count} = Accounts.list_account_shippers(shipper, filters)

      conn
      |> render("index.json", shippers: shippers, page_count: page_count)
    end
  end
end
