defmodule FraytElixirWeb.AdminAddCompanyLive do
  use Phoenix.LiveView
  import FraytElixirWeb.CreateUpdateCompany
  alias FraytElixir.Accounts
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

  @empty_company [:name, :invoice_period, :account_billing_enabled, :sales_rep_id, :email]
  @empty_location [
    location: [
      :location,
      :store_number,
      :invoice_period,
      :replace_locations,
      :sales_rep_id,
      :email,
      :account_billing_enabled
    ],
    address: [:address, :address2, :city, :state, :zip]
  ]

  def mount(_params, session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      {:ok,
       assign(socket, %{
         display_form: session["default_form"],
         chosen_company: session["chosen_company"],
         chosen_company_name: session["chosen_company_name"],
         new_company: Enum.reduce(@empty_company, %{}, &Map.put(&2, &1, nil)),
         new_location: empty_location_with_sales_rep_and_billing(session["chosen_company"]),
         errors: []
       })}
    end)
  end

  def handle_event(
        "change_form",
        %{"_target" => ["account-billing"], "account-billing" => account_billing} = form,
        socket
      ) do
    live_view_action(__MODULE__, "change_form", socket, fn ->
      attrs = %{
        name: form["company-name"],
        invoice_period: form["company-terms"],
        account_billing_enabled: account_billing == "true",
        sales_rep_id: form["sales-rep"],
        email: form["company-email"]
      }

      {:noreply, assign(socket, %{new_company: attrs})}
    end)
  end

  def handle_event("change_form", _event, socket) do
    live_view_action(__MODULE__, "change_form", socket, fn ->
      {:noreply, socket}
    end)
  end

  def handle_event("close_modal", _event, socket) do
    live_view_action(__MODULE__, "close_modal", socket, fn ->
      send(socket.parent_pid, :close_modal)
      {:noreply, socket}
    end)
  end

  def handle_event("next_page", form, socket) do
    live_view_action(__MODULE__, "next_company_page", socket, fn ->
      company_from_form(form)
      |> next_page(socket)
    end)
  end

  def handle_event("submit", location_form, socket) do
    live_view_action(__MODULE__, "submit", socket, fn ->
      create_company_attrs(location_form, socket.assigns)
      |> submit(socket, location_form)
    end)
  end

  def empty_location_with_sales_rep_and_billing(company_id) do
    Enum.reduce(@empty_location, %{}, &set_field_grouping(&1, &2, company_id))
  end

  def set_field_grouping({group, field}, final_empty_location, company_id),
    do:
      Map.put(
        final_empty_location,
        group,
        Enum.reduce(field, %{}, &give_value_to_field(&1, &2, company_id))
      )

  def give_value_to_field(field_name, grouping, company_id),
    do: Map.put(grouping, field_name, set_value(field_name, company_id))

  def set_value(:invoice_period, company_id), do: Accounts.get_company_invoice_period(company_id)

  def set_value(:sales_rep_id, company_id), do: Accounts.get_company_sales_rep_id(company_id)

  def set_value(:account_billing_enabled, company_id),
    do: Accounts.company_has_account_billing?(company_id)

  def set_value(_field, _company_id), do: nil

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("add_company.html", assigns)
  end
end
