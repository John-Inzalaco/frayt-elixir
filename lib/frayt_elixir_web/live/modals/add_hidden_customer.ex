defmodule FraytElixirWeb.AddHiddenCustomer do
  use FraytElixirWeb, :live_modal
  import Phoenix.HTML.Form
  import FraytElixirWeb.ErrorHelpers
  import FraytElixirWeb.LiveViewHelpers

  alias FraytElixir.Drivers.{HiddenCustomer, Driver}
  alias FraytElixir.Accounts.{Shipper, Company}
  alias FraytElixir.Repo

  def mount(
        _params,
        %{
          "driver" => driver
        },
        socket
      ) do
    {:ok,
     assign(socket,
       driver: driver,
       changeset: HiddenCustomer.changeset(%HiddenCustomer{}, %{}),
       customer_type: :company
     )}
  end

  def handle_event(
        "change",
        %{
          "_target" => ["hidden_customer", "customer_type"],
          "hidden_customer" => %{"reason" => reason, "customer_type" => customer_type}
        },
        socket
      ) do
    changeset = HiddenCustomer.changeset(%HiddenCustomer{}, %{"reason" => reason})

    {:noreply,
     assign(socket, %{changeset: changeset, customer_type: String.to_existing_atom(customer_type)})}
  end

  def handle_event("change", %{"hidden_customer" => attrs}, socket) do
    changeset =
      %HiddenCustomer{}
      |> HiddenCustomer.changeset(attrs)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, %{changeset: changeset})}
  end

  def handle_event("save", %{"hidden_customer" => attrs}, %{assigns: %{driver: driver}} = socket) do
    changeset = HiddenCustomer.changeset(%HiddenCustomer{}, attrs)

    case Repo.insert(changeset) do
      {:ok, hidden_customer} ->
        hidden_customer = Repo.preload(hidden_customer, shipper: :user, company: [])

        driver = %Driver{
          driver
          | hidden_customers: driver.hidden_customers ++ [hidden_customer]
        }

        send(socket.parent_pid, {:driver_updated, driver})

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
      <%= f = form_for @changeset, "#", [phx_submit: "save", phx_change: "change"] %>
        <%= hidden_input f, :driver_id, value: @driver.id %>
        <div class="width--full">
          <div class="u-push__top--sm">
            <%= label f, :customer_type, "Customer Type" %>
            <%= select f, :customer_type, [Shipper: :shipper, Company: :company], selected: @customer_type %>
            <span class="error"><%= error_tag f, :customer_type %></span>
          </div>
          <div class="u-push__top--sm">
            <%= if @customer_type == :company do %>
              <%= label f, :company_id, "Company" %>
              <%= record_select(f, :company_id, Company, allow_empty: false) %>
            <% else %>
              <%= label f, :shipper_id, "Shipper" %>
              <%= record_select(f, :shipper_id, Shipper, allow_empty: false) %>
            <% end %>
            <span class="error"><%= error_tag f, :company_id %></span>
            <span class="error"><%= error_tag f, :driver_id_company_id %></span>
            <span class="error"><%= error_tag f, :shipper_id %></span>
            <span class="error"><%= error_tag f, :driver_id_shipper_id %></span>
          </div>
          <div class="u-push__top--sm">
            <%= label f, :reason, "Reason" %>
            <%= textarea f, :reason %>
            <span class="error"><%= error_tag f, :reason %></span>
          </div>
          <div class="u-push__top">
            <button class="button button--primary" type="submit">Save</button>
            <a onclick="" tabindex=0 phx-click="close_modal" class="button">Cancel</a>
          </div>
        </div>
      </form>
    """
  end
end
