defmodule FraytElixirWeb.Admin.DriverShowLive do
  alias FraytElixir.{Drivers, Payments, Screenings, Repo, LiveAction, DriverDocuments}
  alias Drivers.Driver
  use FraytElixirWeb, :live_view
  use LiveAction
  use FraytElixirWeb.ModalEvents

  def mount(params, _session, socket) do
    {:ok,
     assign(socket, %{
       driver: get_driver(params["id"]),
       show_buttons: false,
       errors: nil,
       title: nil,
       show_modal: false,
       editing: false,
       vehicle_id: nil,
       images: "",
       create_wallet: LiveAction.new(),
       refresh_turn_status: LiveAction.new(),
       start_background_check: LiveAction.new(),
       active_matches: Drivers.active_matches_count(params["id"])
     })}
  end

  def handle_event("change_penalties", %{"penaltynumber" => number}, socket) do
    {message, driver} = change_penalties(socket.assigns.driver, number)

    case message do
      :ok -> {:noreply, assign(socket, :driver, driver |> preload_driver())}
      :error -> {:noreply, socket}
    end
  end

  def handle_event(
        "delete_hidden_customer:" <> hidden_customer_id,
        _event,
        %{assigns: %{driver: driver}} = socket
      ) do
    case Drivers.delete_hidden_customer(hidden_customer_id) do
      {:ok, _} ->
        driver = %Driver{
          driver
          | hidden_customers: Enum.filter(driver.hidden_customers, &(&1.id != hidden_customer_id))
        }

        {:noreply, assign(socket, %{driver: driver})}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edit_personal_information", _event, socket) do
    {:noreply, assign(socket, :editing, "personal")}
  end

  def handle_event("edit_vehicle", %{"vehicleid" => vehicle_id}, socket) do
    {:noreply, assign(socket, :editing, vehicle_id)}
  end

  def handle_event("open_notes", _event, socket) do
    {:noreply, assign(socket, :show_buttons, true)}
  end

  def handle_event("close_notes", _event, socket) do
    {:noreply, assign(socket, %{show_buttons: false, errors: nil})}
  end

  def handle_event("save_notes", %{"driver-notes" => notes}, socket) do
    {message, driver} = Drivers.update_driver(socket.assigns.driver, %{notes: notes})

    case message do
      :ok -> {:noreply, assign(socket, %{driver: driver, errors: nil, show_buttons: false})}
      :error -> {:noreply, assign(socket, :errors, "something went wrong")}
    end
  end

  def handle_event("start_background_check", _event, socket) do
    socket =
      LiveAction.start(socket, :start_background_check, fn ->
        with {:ok, driver} <- Screenings.start_background_check(socket.assigns.driver) do
          socket = assign(socket, :driver, driver)
          {:ok, driver, socket}
        end
      end)

    {:noreply, socket}
  end

  def handle_event("reactivate_driver", _event, socket) do
    case Drivers.reactivate_driver(socket.assigns.driver) do
      {:ok, driver} -> {:noreply, assign(socket, %{driver: driver})}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("create_branch_wallet", _event, socket) do
    socket =
      LiveAction.start(socket, :create_wallet, fn ->
        with {:ok, driver} <- Payments.create_wallet(socket.assigns.driver) do
          socket = assign(socket, :driver, driver)
          {:ok, driver, socket}
        end
      end)

    {:noreply, socket}
  end

  def handle_event("refresh_turn_status", _event, socket) do
    socket =
      LiveAction.start(socket, :refresh_turn_status, fn ->
        driver = socket.assigns.driver

        with {:ok, driver} <- Screenings.refresh_background_check_turn_status(driver) do
          socket = assign(socket, :driver, driver)

          {:ok, driver, socket}
        end
      end)

    {:noreply, socket}
  end

  def handle_info({:driver_updated, new_driver}, socket) do
    {:noreply,
     assign(socket, %{editing: nil, show_modal: false, driver: new_driver |> preload_driver()})}
  end

  def handle_info(:close_edit, socket) do
    {:noreply, assign(socket, %{editing: false})}
  end

  def change_penalties(%Driver{penalties: 1} = driver, "1"),
    do: Drivers.update_driver(driver, %{penalties: 0})

  def change_penalties(%Driver{} = driver, number),
    do: Drivers.update_driver(driver, %{penalties: number})

  defp get_driver(id),
    do:
      Drivers.get_driver(id)
      |> preload_driver()

  defp preload_driver(driver),
    do:
      driver
      |> Repo.preload([
        :metrics,
        :market,
        :default_device,
        background_check: Screenings.latest_background_check_query(),
        images: DriverDocuments.latest_driver_documents_query(),
        hidden_customers: [shipper: :user, company: []],
        vehicles: [images: DriverDocuments.latest_vehicle_documents_query()]
      ])

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("driver_show.html", assigns)
  end
end
