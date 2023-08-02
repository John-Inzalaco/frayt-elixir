defmodule FraytElixirWeb.Admin.CompanyDetailsLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/companies/{parent_id}",
    default_filters: %{order_by: :location, per_page: 4},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :parent_id, type: :string, default: "id"}
    ],
    model: :locations,
    embedded?: true

  use FraytElixirWeb.ModalEvents
  use FraytElixirWeb.AdminAlerts
  alias FraytElixir.{Accounts, Repo}
  alias Accounts.Company
  alias FraytElixirWeb.DisplayFunctions
  import FraytElixirWeb.CreateUpdateCompany

  def mount(params, _session, socket) do
    company_id = params["id"]
    company = find_company(company_id)

    socket =
      socket
      |> assign(%{
        company: company,
        company_changeset: nil,
        editing: false,
        default_form: :location,
        title: "Add Location",
        attrs: %{},
        show_modal: false,
        errors: %{}
      })

    {:ok, socket}
  end

  def handle_event("cancel_edit", _, socket), do: {:noreply, cancel_edit(socket)}

  def handle_event(
        "change_edit_company",
        %{
          "edit_company_form" => edit_form
        },
        socket
      ) do
    attrs = format_form_attrs(edit_form)

    {:noreply, assign(socket, %{edit_form: attrs})}
  end

  def handle_event("change_edit_" <> _form, _event, socket) do
    {:noreply, socket}
  end

  @editable_fields ~w(
    email sales_rep_id name invoice_period account_billing_enabled
    is_enterprise auto_cancel auto_cancel_on_driver_cancel
    autoselect_vehicle_class origin_photo_required destination_photo_required
    signature_required default_contract_id
  )a

  def handle_event("edit_company", _event, %{assigns: %{company: company}} = socket) do
    {:noreply,
     socket
     |> start_edit("company")
     |> assign(%{
       edit_form:
         company
         |> Map.take(@editable_fields)
         |> Map.put(:replace_sales_rep, false)
         |> Map.put(:replace_invoice_period, false)
     })}
  end

  def handle_event("save_edit_company", %{"edit_company_form" => edit_form}, socket) do
    company = socket.assigns.company

    {company, attrs} =
      format_form_attrs(edit_form)
      |> case do
        %{replace_sales_rep: false, replace_invoice_period: false} = attrs ->
          {company, attrs}

        attrs ->
          company = company |> Repo.preload(locations: :shippers)

          {company,
           Map.put(
             attrs,
             :locations,
             Enum.map(
               company.locations,
               &%{
                 id: &1.id,
                 sales_rep_id: maybe_replace_sales_rep(edit_form, &1),
                 shippers: shipper_replacement(edit_form, &1.shippers),
                 invoice_period: maybe_replace_invoice_period(edit_form, &1)
               }
             )
           )}
      end

    Accounts.update_company(company, attrs)
    |> case do
      {:ok, _} ->
        {:noreply,
         socket
         |> cancel_edit()
         |> assign(:company, find_company(socket.assigns.company.id))}

      {:error, changeset} ->
        {:noreply,
         assign(socket, %{errors: DisplayFunctions.translate_errors(changeset), edit_form: attrs})}
    end
  end

  def handle_event("add_location", _event, socket) do
    {:noreply,
     assign(open_modal(socket), %{
       default_form: :location,
       title: "Add Location"
     })}
  end

  def handle_event("edit_" <> form, _params, socket) do
    {:noreply,
     socket
     |> start_edit(form)
     |> assign(:company_changeset, Company.changeset(socket.assigns.company, %{}))}
  end

  def handle_event("change", %{"company" => attrs}, socket) do
    {:noreply,
     socket
     |> assign(
       :company_changeset,
       socket.assigns.company
       |> Company.changeset(attrs)
       |> Map.put(:action, :insert)
     )}
  end

  def handle_event("update", %{"company" => attrs}, socket) do
    changeset = Company.changeset(socket.assigns.company, attrs)

    case Repo.update(changeset) do
      {:ok, company} ->
        send_alert(:info, "Updated Company successfully")

        {:noreply,
         socket
         |> cancel_edit()
         |> assign(:company, company)}

      {:error, changeset} ->
        {:noreply, assign(socket, :company_changeset, changeset)}
    end
  end

  def handle_event("create_api_account", _, socket) do
    case Accounts.create_api_account(socket.assigns.company) do
      {:ok, api_account} ->
        send_alert(:info, "Created API Account")
        {:noreply, assign(socket, :company, %{socket.assigns.company | api_account: api_account})}

      error ->
        send_alert(:danger, DisplayFunctions.humanize_update_errors(error, "API Account"))
    end
  end

  def handle_event("revoke_api_account", _, socket) do
    case Accounts.delete_api_account(socket.assigns.company.api_account) do
      {:ok, _} ->
        send_alert(:danger, "Deleted API Account")
        {:noreply, assign(socket, :company, %{socket.assigns.company | api_account: nil})}

      error ->
        send_alert(:danger, DisplayFunctions.humanize_update_errors(error, "API Account"))
    end
  end

  def handle_info({:to_add_shippers, attrs, _company_id, _company_name}, socket) do
    {:noreply,
     assign(socket, %{
       show_modal: true,
       attrs: attrs,
       title: "Add Shippers",
       default_form: :shipper
     })}
  end

  def handle_info(:new_shipper_added, socket) do
    socket = update_results(socket)

    {:noreply,
     assign(socket, %{
       show_modal: false,
       company: find_company(socket.assigns.company.id)
     })}
  end

  def list_records(socket, filters), do: {socket, Accounts.list_locations(filters)}

  def find_company(company_id),
    do:
      company_id
      |> Accounts.get_company!()
      |> Repo.preload([:api_account, :default_contract, :contracts, sales_rep: :user])

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("company_details.html", assigns)
  end

  defp start_edit(socket, form) do
    assign(socket, %{
      editing: form,
      errors: %{}
    })
  end

  defp cancel_edit(socket) do
    assign(socket, %{
      editing: nil,
      company_changeset: nil,
      edit_form: %{},
      errors: %{}
    })
  end
end
