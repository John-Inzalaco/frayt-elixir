defmodule FraytElixirWeb.Test.LoginHelper do
  alias FraytElixir.{Accounts, Repo}
  alias FraytElixir.Accounts.AdminUser
  alias FraytElixir.Drivers.Driver
  alias FraytElixirWeb.Plugs.Auth
  alias Plug.Conn

  import FraytElixir.Guardian
  import FraytElixir.Factory

  def login_as_shipper(%{conn: conn}) do
    shipper = insert(:shipper, location: build(:location))
    conn = add_token_for_shipper(conn, shipper)
    {:ok, conn: conn, shipper: shipper}
  end

  def login_as_company_admin_shipper(%{conn: conn}) do
    shipper = insert(:shipper_with_location, role: "company_admin")
    conn = add_token_for_shipper(conn, shipper)
    {:ok, conn: conn, shipper: shipper}
  end

  def login_as_shipper_with_contract(conn) do
    contract = insert(:contract, contract_key: "tbc")

    shipper =
      insert(:shipper,
        location:
          insert(:location,
            company:
              insert(:company,
                account_billing_enabled: true,
                default_contract: contract
              )
          )
      )

    contract
    |> Ecto.Changeset.change(%{company_id: shipper.location.company_id})
    |> Repo.update!()

    conn = add_token_for_shipper(conn, shipper)
    {:ok, conn: conn, shipper: shipper}
  end

  def add_token_for_shipper(conn, shipper) do
    user = Accounts.get_user!(shipper.user_id)

    add_token_for_user(conn, user)
  end

  def login_with_api(%{conn: conn}) do
    api_account = insert(:api_account_with_company)
    conn = add_token_for_api_account(conn, api_account)
    {:ok, conn: conn, api_account: api_account}
  end

  def login_as_driver(%{conn: conn}) do
    driver = insert(:driver)
    driver = set_driver_default_device(driver)
    conn = add_token_for_driver(conn, driver)
    {:ok, conn: conn, driver: driver}
  end

  def login_as_driver_with_wallet(%{conn: conn}) do
    driver = insert(:driver_with_wallet)
    driver = set_driver_default_device(driver)
    conn = add_token_for_driver(conn, driver)
    {:ok, conn: conn, driver: driver}
  end

  def login_as_driver(conn, %Driver{} = driver) do
    driver = set_driver_default_device(driver)
    conn = add_token_for_driver(conn, driver)
    {:ok, conn: conn, driver: driver}
  end

  def add_token_for_driver(conn, driver) do
    user = Accounts.get_user!(driver.user_id)
    add_token_for_user(conn, user)
  end

  def add_token_for_user(conn, user) do
    {:ok, token, _} = encode_and_sign(user)

    conn |> Conn.put_req_header("authorization", "bearer: " <> token)
  end

  def add_token_for_api_account(conn, api_account) do
    {:ok, token, _} = encode_and_sign(api_account, %{aud: "frayt_api"})

    conn |> Conn.put_req_header("authorization", "bearer: " <> token)
  end

  def logout(conn) do
    req_headers =
      conn
      |> Map.get(:req_headers)
      |> Enum.filter(&(elem(&1, 0) != "authorization"))

    Map.put(conn, :req_headers, req_headers)
  end

  def login_as_admin(%{conn: conn}) do
    %AdminUser{user: admin} = insert(:admin_user)
    conn = Auth.build_session(conn, admin)
    {:ok, conn: conn, admin: admin}
  end

  def login_as_user(%{conn: conn}) do
    user = insert(:user)
    conn = Auth.build_session(conn, user)
    {:ok, conn: conn, user: user}
  end

  def login_user(conn, user), do: Auth.build_session(conn, user)
end
