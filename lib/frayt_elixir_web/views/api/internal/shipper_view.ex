defmodule FraytElixirWeb.API.Internal.ShipperView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.{ShipperView, AgreementDocumentView, ContractView}
  alias FraytElixirWeb.LocationView
  alias FraytElixirWeb.AddressView
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.{ShipperRole, Shipper, User, Company, Location}
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Repo

  @shipper_layouts ["shipper.json", "personal_shipper.json"]

  def render("index.json", %{shippers: shippers, page_count: page_count}) do
    %{data: render_many(shippers, ShipperView, "shipper.json"), page_count: page_count}
  end

  def render("show_personal.json", %{shipper: shipper}) do
    %{response: render_one(shipper, ShipperView, "personal_shipper.json")}
  end

  def render("show.json", %{shipper: shipper}) do
    %{response: render_one(shipper, ShipperView, "shipper.json")}
  end

  def render(layout, %{shipper: %Shipper{user: %NotLoaded{}} = shipper})
      when layout in @shipper_layouts do
    shipper = shipper |> Repo.preload(:user)
    render(layout, %{shipper: shipper})
  end

  def render("personal_shipper.json", %{
        shipper: shipper
      }) do
    pending_agreements = Accounts.list_pending_agreements(shipper)

    %Shipper{
      address: address,
      agreement: agreement,
      referrer: referrer,
      texting: texting,
      commercial: commercial,
      user: %User{password_reset_code: code},
      location: location
    } =
      shipper
      |> Repo.preload([:address, {:location, [company: [:locations, :contracts]]}])

    company =
      case location do
        %Location{
          company: %Company{
            id: company_id,
            name: company_name,
            account_billing_enabled: account_billing_enabled,
            invoice_period: invoice_period,
            locations: locations,
            contracts: contracts
          }
        } ->
          %{
            id: company_id,
            name: company_name,
            account_billing_enabled: account_billing_enabled,
            invoice_period: invoice_period,
            locations: render_many(locations, LocationView, "location.json"),
            contracts: render_many(contracts, ContractView, "contract.json")
          }

        _ ->
          shipper.company
      end

    render("shipper.json", %{shipper: shipper})
    |> Map.merge(%{
      address: render_one(address, AddressView, "address.json"),
      agreement: agreement,
      referrer: referrer,
      texting: texting,
      password_reset_code: !is_nil(code),
      commercial: commercial,
      location: render_one(location, LocationView, "location.json"),
      company: company,
      pending_agreements:
        render_many(pending_agreements, AgreementDocumentView, "agreement_document.json")
    })
  end

  def render("shipper.json", %{shipper: shipper}) do
    %Shipper{
      id: id,
      phone: phone,
      first_name: first_name,
      last_name: last_name,
      role: role,
      user: %User{email: email},
      address: address,
      state: state,
      location: location
    } = Repo.preload(shipper, [:location, :address])

    %{
      id: id,
      phone: phone,
      first_name: first_name,
      last_name: last_name,
      email: email,
      role: role,
      role_label: ShipperRole.name(role),
      state: state,
      location: render_one(location, LocationView, "location.json"),
      address: render_one(address, AddressView, "address.json")
    }
  end
end
