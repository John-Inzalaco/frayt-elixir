defmodule FraytElixirWeb.Admin.CreateMatchLive do
  use FraytElixirWeb, :live_view
  alias FraytElixir.{Accounts, Shipment, Matches}
  import FraytElixir.AtomizeKeys
  alias Shipment.Match
  alias FraytElixir.Accounts.{Company, Location, Shipper, User}
  alias FraytElixir.Payments.CreditCard

  import FraytElixirWeb.DisplayFunctions,
    only: [create_datetime: 4, humanize_errors: 1]

  @generic_error [general: {"Something went wrong"}]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, %{
       match: %{
         scheduled: "false",
         dropoff_asap: "false",
         coupon: "",
         origin_address: "",
         destination_address: "",
         shipper: %Shipper{user: %User{email: ""}},
         pieces: "",
         weight: "",
         length: "",
         height: "",
         width: "",
         po: "",
         dropoff_at: "",
         pickup_at: "",
         dropoff_at_date: "",
         dropoff_at_time: "",
         pickup_at_date: "",
         pickup_at_time: "",
         delivery_notes: "",
         pickup_notes: "",
         description: "",
         self_recipient: "false",
         recipient_name: "",
         recipient_email: "",
         recipient_phone: "",
         has_load_fee: "false",
         service_level: "1",
         vehicle_class: "1",
         network_operator_id: ""
       },
       errors: [],
       found_shipper: false
     })}
  end

  defp maybe_add_error(errors, _key, [], _error_message), do: errors

  defp maybe_add_error(errors, key, _error_list, error_message),
    do: Keyword.put(errors, key, {error_message})

  defp try_create_match(attrs, shipper, admin) do
    case attrs
         |> Matches.convert_attrs_to_multi_stop()
         |> Matches.create_match(shipper, admin) do
      {:ok, match} -> {:ok, match}
      {:error, code, error, _data} -> handle_errors(code, error, attrs)
      _ -> {@generic_error, attrs}
    end
  end

  defp handle_errors(
         _code,
         %Ecto.Changeset{
           errors: match_errors,
           changes:
             %{
               match_stops: [
                 %Ecto.Changeset{
                   changes:
                     %{
                       destination_address: %Ecto.Changeset{
                         changes: destination_address_changes,
                         errors: destination_address_errors
                       },
                       items: [
                         %Ecto.Changeset{
                           errors: item_errors
                         }
                       ]
                     } = stop_changes,
                   errors: match_stop_errors
                 }
               ],
               origin_address: %Ecto.Changeset{
                 changes: origin_address_changes,
                 errors: origin_address_errors
               }
             } = changes
         } = changeset,
         match_attrs
       ) do
    coupon_errors = Map.get(changes, :shipper_match_coupon, %{}) |> Map.get(:errors, [])

    recipient_errors = (Map.get(stop_changes, :recipient) || %{}) |> Map.get(:errors, [])

    errors =
      (match_errors ++
         match_stop_errors ++ coupon_errors ++ item_errors ++ [recipient: recipient_errors])
      |> maybe_add_error(:origin_address, origin_address_errors, "address is invalid")
      |> maybe_add_error(
        :destination_address,
        destination_address_errors,
        "address is invalid"
      )
      |> Keyword.put(:general, {humanize_errors(changeset)})

    {errors,
     Map.merge(match_attrs, %{
       origin_address:
         Map.get(origin_address_changes, :formatted_address, match_attrs.origin_address),
       destination_address:
         Map.get(
           destination_address_changes,
           :formatted_address,
           match_attrs.destination_address
         )
     })}
  end

  defp handle_errors(_code, message, match_attrs) when is_binary(message),
    do: {[general: {message}], match_attrs}

  defp handle_errors(_, _, match_attrs), do: {@generic_error, match_attrs}

  def handle_event(
        "create_match",
        _event,
        socket
      ) do
    %{current_user: %{admin: admin}} = socket.assigns

    shipper =
      case socket.assigns.match.shipper.user.email
           |> Accounts.get_shipper_by_email()
           |> FraytElixir.Repo.preload([:user, :credit_card, location: [:company]]) do
        %Shipper{} = found_shipper -> found_shipper
        nil -> socket.assigns.match.shipper
      end

    match_attrs =
      Map.merge(socket.assigns.match, %{
        autoselect_vehicle: false,
        scheduled: socket.assigns.match.scheduled == "true"
      })

    case try_create_match(match_attrs, shipper, admin) do
      {:ok, %Match{id: match_id}} ->
        {:noreply, redirect(socket, to: "/admin/matches/#{match_id}")}

      {errors, match} ->
        {:noreply, assign(socket, errors: errors, match: match)}
    end
  end

  def handle_event(
        "change_shipper",
        %{"search_shipper" => %{"shipper_email" => shipper_email}},
        socket
      ) do
    {:noreply,
     assign(socket, %{
       found_shipper: false,
       match: %{socket.assigns.match | shipper: %Shipper{user: %User{email: shipper_email}}}
     })}
  end

  def handle_event(
        "search_shippers",
        %{"search_shipper" => %{"shipper_email" => shipper_email}},
        socket
      ) do
    assigns =
      case Accounts.get_shipper_by_email(shipper_email) do
        %Shipper{} = shipper ->
          shipper = FraytElixir.Repo.preload(shipper, [:user, :credit_card, location: [:company]])

          %{
            found_shipper: true,
            match: Map.put(socket.assigns.match, :shipper, shipper),
            errors:
              case has_payment_options(shipper) do
                true ->
                  Keyword.delete(socket.assigns.errors, :shipper)

                false ->
                  Keyword.put(
                    socket.assigns.errors,
                    :shipper_id,
                    {"Shipper does not have payments set up"}
                  )
              end
          }

        nil ->
          %{
            found_shipper: false,
            match:
              Map.put(socket.assigns.match, :shipper, %Shipper{user: %User{email: shipper_email}}),
            errors:
              Keyword.put(
                socket.assigns.errors,
                :shipper_id,
                {"Shipper does not exist"}
              )
          }
      end

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("toggle_slider", %{"field" => string_field}, socket) do
    field = String.to_existing_atom(string_field)

    {:noreply,
     assign(socket, %{
       match:
         transform_fields(
           Map.put(socket.assigns.match, field, toggle_field(socket.assigns.match[field])),
           socket.assigns.time_zone,
           socket.assigns.match.shipper
         )
     })}
  end

  def handle_event(
        "change_match",
        %{
          "match" => form
        },
        socket
      ) do
    fields =
      atomize_keys(form)
      |> transform_fields(socket.assigns.time_zone, socket.assigns.match.shipper)

    {:noreply,
     assign(socket, %{
       match: fields
     })}
  end

  defp transform_fields(
         %{
           scheduled: scheduled,
           dropoff_asap: dropoff_asap,
           self_recipient: self_recipient,
           dropoff_at_date: dropoff_date,
           dropoff_at_time: dropoff_time,
           pickup_at_date: pickup_date,
           pickup_at_time: pickup_time
         } = fields,
         time_zone,
         shipper
       ),
       do:
         Map.merge(fields, %{
           shipper: shipper,
           pickup_at: create_datetime(pickup_date, pickup_time, scheduled, time_zone),
           self_recipient: self_recipient,
           dropoff_at:
             create_datetime(
               dropoff_date,
               dropoff_time,
               has_dropoff(scheduled, dropoff_asap),
               time_zone
             )
         })

  defp has_dropoff(scheduled, dropoff_asap),
    do: to_string(scheduled == "true" and dropoff_asap == "false")

  defp toggle_field("true"), do: "false"
  defp toggle_field("false"), do: "true"
  defp toggle_field(true), do: "false"
  defp toggle_field(false), do: "true"

  defp has_payment_options(%Shipper{
         location: %Location{company: %Company{account_billing_enabled: true}}
       }),
       do: true

  defp has_payment_options(%Shipper{
         credit_card: %CreditCard{}
       }),
       do: true

  defp has_payment_options(_), do: false

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("create_match.html", assigns)
  end
end
