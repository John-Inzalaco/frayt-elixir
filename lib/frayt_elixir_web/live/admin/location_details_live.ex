defmodule FraytElixirWeb.Admin.LocationDetailsLive do
  use FraytElixirWeb, :live_view
  use FraytElixirWeb.ModalEvents
  alias FraytElixir.Accounts
  alias Accounts.Schedule
  alias FraytElixir.Notifications.DriverNotification
  import FraytElixirWeb.CreateUpdateCompany
  alias Timex

  @weekdays ~w[monday tuesday wednesday thursday friday saturday sunday]a

  def mount(params, _session, socket) do
    company_id = params["company_id"]
    location = get_location(params["location_id"])

    socket =
      socket
      |> assign(%{
        location: location,
        schedule: location.schedule,
        company: location.company,
        company_id: company_id,
        editing: false,
        attrs: nil,
        editing_schedule: false,
        errors: [],
        show_modal: false,
        fleet_notification_radius: 60
      })

    {:ok, socket}
  end

  defp convert_times_to_utc(attrs, timezone),
    do:
      Enum.map(attrs, fn {key, value} ->
        case key in @weekdays do
          true -> {key, convert_time(value, timezone)}
          _ -> {key, value}
        end
      end)

  defp convert_time("", _), do: nil

  defp convert_time(time, timezone) when is_binary(time),
    do: String.split(time, ":") |> Enum.map(&String.to_integer/1) |> convert_time(timezone)

  defp convert_time([hours, minutes], timezone),
    do: Time.new(hours, minutes, 0) |> elem(1) |> convert_time(timezone)

  defp convert_time(time, timezone) do
    case NaiveDateTime.new(Date.utc_today(), time) do
      {:ok, ndt} ->
        Timex.to_datetime(ndt, timezone)
        |> Timex.Timezone.convert("Etc/UTC")
        |> DateTime.to_time()

      _ ->
        nil
    end
  end

  defp create_or_update_schedule(
         %{send_notifications: send_notifications, exclude_notified: exclude_notified} = attrs,
         socket,
         nil
       ) do
    case Accounts.create_schedule(attrs) do
      {:ok, schedule} ->
        if send_notifications == "true",
          do: send_notifications(schedule, 60, exclude_notified == "true")

        {:noreply,
         assign(socket, %{
           errors: [],
           schedule: schedule,
           editing_schedule: false,
           location: Map.put(socket.assigns.location, :schedule, schedule)
         })}

      {:error, changeset} ->
        {:noreply, assign(socket, %{errors: changeset.errors, schedule: attrs})}
    end
  end

  defp create_or_update_schedule(
         %{send_notifications: send_notifications, exclude_notified: exclude_notified} = attrs,
         socket,
         schedule
       ) do
    case Accounts.update_schedule(schedule, attrs) do
      {:ok, schedule} ->
        if send_notifications == "true",
          do: send_notifications(schedule, 60, exclude_notified == "true")

        {:noreply,
         assign(socket, %{
           errors: [],
           schedule: Map.from_struct(schedule),
           editing_schedule: false,
           location: Map.put(socket.assigns.location, :schedule, schedule)
         })}

      {:error, changeset} ->
        {:noreply, assign(socket, %{errors: changeset.errors, schedule: attrs})}
    end
  end

  def handle_event("remove_driver_" <> driver_id, _event, socket) do
    Accounts.remove_driver_from_schedule(socket.assigns.location.schedule.id, driver_id)
    location = get_location(socket.assigns.location.id)

    {:noreply,
     assign(socket, %{
       schedule: location.schedule,
       location: location
     })}
  end

  def handle_event("edit_schedule", _event, socket) do
    {:noreply, assign(socket, :editing_schedule, true)}
  end

  def handle_event("cancel_edit_schedule", _, socket) do
    {:noreply, assign(socket, %{errors: [], editing_schedule: false})}
  end

  def handle_event(
        "save_edit_schedule",
        %{
          "schedule_form" => schedule_form
        },
        socket
      ) do
    attrs =
      atomize_keys(schedule_form)
      |> convert_times_to_utc(socket.assigns.time_zone)
      |> Enum.into(%{})
      |> Map.put(:location_id, socket.assigns.location.id)

    create_or_update_schedule(attrs, socket, socket.assigns.location.schedule)
  end

  def handle_event(
        "send_fleet_notifications",
        %{
          "fleet_notification_form" => %{
            "radius" => radius,
            "exclude_notified" => exclude_notified
          }
        },
        %{
          assigns: %{location: %{schedule: schedule}}
        } = socket
      ) do
    send_notifications(schedule, radius, exclude_notified == "true")
    {:noreply, put_flash(socket, :info, "Drivers have been notified.")}
  end

  def handle_event("cancel_edit_location", _, socket) do
    {:noreply, assign(socket, %{editing: false, errors: [], edit_form: %{}})}
  end

  def handle_event(
        "change_edit_location",
        %{
          "_target" => ["edit_location_form", "replace_sales_rep"],
          "edit_location_form" => edit_form
        },
        socket
      ) do
    attrs = format_form_attrs(edit_form)

    {:noreply, assign(socket, %{fields: attrs})}
  end

  def handle_event(
        "change_edit_location",
        %{
          "_target" => ["edit_location_form", "account_billing_enabled"],
          "edit_location_form" => edit_form
        },
        socket
      ) do
    attrs =
      atomize_keys(edit_form)
      |> Map.put(
        :account_billing_enabled,
        edit_form["account_billing_enabled"] == "true"
      )
      |> Map.put(:address, %{
        address: edit_form["address"],
        address2: edit_form["address2"],
        city: edit_form["city"],
        state: edit_form["state"],
        zip: edit_form["zip"]
      })

    {:noreply, assign(socket, %{edit_form: attrs})}
  end

  def handle_event("change_edit_location", _event, socket) do
    {:noreply, socket}
  end

  def handle_event("edit_location", _event, socket) do
    location = socket.assigns.location

    {:noreply,
     assign(socket, %{
       editing: true,
       errors: [],
       edit_form: %{
         location: location.location,
         replace_sales_rep: false,
         sales_rep_id: location.sales_rep_id,
         store_number: location.store_number,
         email: location.email,
         invoice_period: location.invoice_period,
         account_billing_enabled: not is_nil(location.invoice_period),
         address: location.address
       }
     })}
  end

  def handle_event("save_edit_location", %{"edit_location_form" => edit_form}, socket) do
    location = socket.assigns.location

    attrs =
      atomize_keys(edit_form)
      |> Map.put(:address, %{
        id: location.address.id,
        address: edit_form["address"],
        address2: edit_form["address2"],
        city: edit_form["city"],
        state: edit_form["state"],
        zip: edit_form["zip"]
      })
      |> Map.put(:shippers, shipper_replacement(edit_form, location.shippers))

    Accounts.update_location(location, attrs)
    |> case do
      {:ok, _} ->
        {:noreply,
         assign(socket, %{
           location: get_location(socket.assigns.location.id),
           edit_form: %{},
           editing: false,
           errors: []
         })}

      {:error, changeset} ->
        address_errors =
          Map.get(changeset.changes, :address, %{errors: []})
          |> Map.get(:errors, [])

        {:noreply,
         assign(socket, %{
           edit_form: attrs,
           errors: changeset.errors ++ address_errors
         })}
    end
  end

  def handle_event("remove_shipper_" <> shipper_id, _event, socket) do
    Accounts.update_shipper(Accounts.get_shipper!(shipper_id), %{location_id: nil, company: nil})
    location = get_location(socket.assigns.location.id)

    {:noreply,
     assign(socket, %{
       location: location,
       schedule: location.schedule
     })}
  end

  def handle_info(:new_shipper_added, socket) do
    location = get_location(socket.assigns.location.id)

    {:noreply,
     assign(socket, %{
       show_modal: false,
       location: location,
       schedule: location.schedule
     })}
  end

  defp send_notifications(%Schedule{} = schedule, radius, exclude_notified),
    do:
      DriverNotification.send_fleet_opportunity_notifications(schedule, radius, exclude_notified)

  def get_location(location_id),
    do:
      Accounts.get_location!(location_id)
      |> FraytElixir.Repo.preload([
        :address,
        :company,
        schedule: [drivers: :user],
        shippers: :user,
        sales_rep: :user
      ])

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("location_details.html", assigns)
  end
end
