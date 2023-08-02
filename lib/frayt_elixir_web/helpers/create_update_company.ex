defmodule FraytElixirWeb.CreateUpdateCompany do
  alias FraytElixir.Accounts
  alias Accounts.{Location, Company}
  alias FraytElixir.Shipment.Address
  import Phoenix.LiveView
  import FraytElixir.AtomizeKeys

  @checkbox_fields ~w(
    replace_invoice_period account_billing_enabled replace_sales_rep is_enterprise
    auto_cancel autoselect_vehicle_class auto_cancel_on_driver_cancel
    origin_photo_required destination_photo_required signature_required
  )

  def submit(attrs, socket, location_form) do
    validate_location_form(attrs)
    |> submit_response(attrs, socket, location_form)
  end

  def submit_response(errors, attrs, socket, location_form) when length(errors) > 0,
    do:
      {:noreply,
       assign(socket, %{
         errors: errors,
         new_location: Map.put(attrs, :shippers, %{users: location_form["users-emails"]})
       })}

  def submit_response(_errors, attrs, socket, _location_form) do
    send(
      socket.parent_pid,
      {:to_add_shippers, attrs, socket.assigns.chosen_company, socket.assigns.chosen_company_name}
    )

    {:noreply, assign(socket, :errors, [])}
  end

  def create_or_update_company(attrs, chosen_company) when is_nil(chosen_company),
    do: Accounts.create_company(attrs)

  def create_or_update_company(attrs, _chosen_company),
    do: Accounts.update_company_locations(attrs)

  def create_company_attrs(form, assigns),
    do: %{
      company: extract_company(assigns),
      location: %{
        account_billing_enabled: get_company_account_billing(assigns),
        location: form["location-name"],
        store_number: form["store-id"],
        email: form["location-email"],
        replace_locations: form["replace-locations"] == "true",
        sales_rep_id: form["sales-rep-id"],
        invoice_period: form["location-terms"]
      },
      address: %{
        address: form["address-1"],
        address2: form["address-2"],
        city: form["city"],
        state: form["state"],
        zip: form["zip-code"]
      }
    }

  def validate_location_form(attrs) do
    Location.validate_company_location(%Location{}, attrs.location).errors ++
      Address.admin_geocoding_changeset(%Address{}, attrs.address).errors
  end

  def get_company_account_billing(%{chosen_company: nil, new_company: new_company}),
    do: new_company.account_billing_enabled

  def get_company_account_billing(%{chosen_company: id}),
    do: Accounts.company_has_account_billing?(id)

  def extract_company(%{chosen_company: nil, new_company: new_company}), do: new_company
  def extract_company(%{chosen_company: id}), do: id

  def company_from_form(form),
    do: %{
      name: form["company-name"],
      email: form["company-email"],
      invoice_period: form["company-terms"],
      account_billing_enabled: form["account-billing"] == "true",
      sales_rep_id: empty_string_is_nil(form["sales-rep-id"])
    }

  def next_page(company, socket) do
    Company.changeset(%Company{}, company)
    |> next_page_response(socket, company)
  end

  def empty_string_is_nil(""), do: nil
  def empty_string_is_nil(string), do: string

  def next_page_response(%Ecto.Changeset{valid?: true}, socket, company) do
    socket =
      assign(socket, %{
        display_form: :location,
        new_location:
          Map.put(
            socket.assigns.new_location,
            :location,
            Map.put(socket.assigns.new_location.location, :sales_rep_id, company.sales_rep_id)
            |> Map.put(:account_billing_enabled, company.account_billing_enabled)
            |> Map.put(:invoice_period, company.invoice_period)
          ),
        new_company: company,
        errors: []
      })

    {:noreply, socket}
  end

  def next_page_response(%Ecto.Changeset{valid?: false, errors: errors}, socket, company),
    do: {:noreply, assign(socket, %{errors: errors, new_company: company})}

  defp merge_with_company_info(nil, _), do: nil

  defp merge_with_company_info(user, %{company_name: company_name, location_id: location_id}),
    do: Map.merge(user, %{company: company_name, location_id: location_id})

  def save_shipper_changes(%Phoenix.LiveView.Socket{assigns: %{location_id: nil}} = socket) do
    socket.assigns.attrs
    |> Map.put(:shippers, %{
      users:
        Enum.reduce(
          socket.assigns.fields,
          [],
          &(&2 ++ [elem(&1, 1).user |> merge_with_company_info(socket.assigns)])
        )
    })
    |> Map.put(:company, socket.assigns.company || socket.assigns.attrs.company)
    |> create_or_update_company(socket.assigns.company)
  end

  def save_shipper_changes(socket) do
    Enum.each(socket.assigns.fields, fn {_key, %{user: shipper, attrs: attrs}} ->
      attrs = attrs |> merge_with_company_info(socket.assigns)
      Accounts.update_shipper(shipper, attrs)
    end)
  end

  def format_form_attrs(form) do
    checkbox_attrs =
      @checkbox_fields
      |> Enum.filter(&Map.has_key?(form, &1))
      |> Enum.map(fn field -> {String.to_atom(field), form[field] == "true"} end)
      |> Enum.into(%{})

    atomize_keys(form)
    |> Map.merge(checkbox_attrs)
    |> Map.put(
      :invoice_period,
      form["invoice_period_hidden_mobile"] || form["invoice_period_hidden"] ||
        form["invoice_period_mobile"] || form["invoice_period"]
    )
  end

  def maybe_replace_invoice_period(
        %{"replace_invoice_period" => "true", "invoice_period_hidden_mobile" => invoice_period},
        _location
      ),
      do: invoice_period

  def maybe_replace_invoice_period(
        %{"replace_invoice_period" => "true", "invoice_period_hidden" => invoice_period},
        _location
      ),
      do: invoice_period

  def maybe_replace_invoice_period(
        %{"replace_invoice_period" => "true", "invoice_period_mobile" => invoice_period},
        _location
      ),
      do: invoice_period

  def maybe_replace_invoice_period(
        %{"replace_invoice_period" => "true", "invoice_period" => invoice_period},
        _location
      ),
      do: invoice_period

  def maybe_replace_invoice_period(%{"replace_invoice_period" => "false"}, location),
    do: location.invoice_period

  def maybe_replace_sales_rep(
        %{"replace_sales_rep" => "true", "sales_rep_id" => sales_rep_id},
        _location
      ),
      do: sales_rep_id

  def maybe_replace_sales_rep(%{"replace_sales_rep" => "false"}, location),
    do: location.sales_rep_id

  def shipper_replacement(%{"sales_rep_id" => sales_rep_id}, shippers),
    do: Enum.map(shippers, &%{id: &1.id, sales_rep_id: sales_rep_id})
end
