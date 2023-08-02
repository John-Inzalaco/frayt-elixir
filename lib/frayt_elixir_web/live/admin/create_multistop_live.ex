defmodule FraytElixirWeb.Admin.CreateMultistopLive do
  use FraytElixirWeb, :live_view
  alias FraytElixir.Accounts

  import FraytElixirWeb.DisplayFunctions,
    only: [display_date: 1, display_time: 2, datetime_with_timezone: 2, title_case: 1]

  @days %{
    monday: 0,
    tuesday: 1,
    wednesday: 2,
    thursday: 3,
    friday: 4,
    saturday: 5,
    sunday: 6
  }

  def mount(_params, _session, socket) do
    companies =
      [{"Choose a company", nil}] ++
        (Accounts.list_companies_with_schedules()
         |> Enum.map(fn %{name: name, id: id} -> {name, id} end))

    {:ok,
     assign(socket, %{
       company: nil,
       company_options: companies,
       location_options: [],
       location: nil,
       pickup_options: []
     })}
  end

  def handle_event(
        "change_options",
        %{
          "_target" => ["deliveries", "company_id"],
          "deliveries" => %{"company_id" => company_id}
        },
        socket
      ) do
    company_id = if company_id in ["", nil], do: nil, else: company_id

    locations =
      if company_id do
        location_opts =
          company_id
          |> Accounts.list_company_locations_with_schedules()
          |> Enum.map(fn %{location: name, store_number: store_number, id: id} ->
            {"#{name}#{if store_number, do: " (##{store_number})"}", id}
          end)

        [{"Choose a location", nil}] ++ location_opts
      else
        []
      end

    {:noreply,
     assign(socket, %{
       company: company_id,
       location_options: locations,
       location: nil
     })}
  end

  def handle_event(
        "change_options",
        %{
          "_target" => ["deliveries", "location_id"],
          "deliveries" => %{"location_id" => location_id}
        },
        socket
      ) do
    location_id = if location_id in ["", nil], do: nil, else: location_id

    pickup_times =
      if location_id do
        create_pickup_options(location_id, socket.assigns.time_zone, DateTime.utc_now())
      else
        []
      end

    {:noreply,
     assign(socket, %{
       location: location_id,
       pickup_options: pickup_times
     })}
  end

  def handle_event("change_options", _event, socket) do
    {:noreply, socket}
  end

  def create_pickup_options(location_id, time_zone, now) do
    Accounts.get_location!(location_id)
    |> Map.get(:schedule)
    |> Map.from_struct()
    |> Enum.reduce([], fn {key, value}, acc ->
      day_keys = Map.keys(@days)

      if key in day_keys and not is_nil(value) do
        acc ++ [{key, value}]
      else
        acc
      end
    end)
    |> Enum.map(fn time -> calculate_next_datetime(time, now, time_zone) end)
    |> Enum.reduce([], fn option, acc -> acc ++ option end)
    |> Enum.sort(&(DateTime.compare(elem(&1, 1), elem(&2, 1)) == :lt))
    |> Enum.map(fn {string, struct} -> {string, DateTime.to_iso8601(struct)} end)
  end

  def calculate_next_datetime({weekday, time}, now, timezone) do
    today = datetime_with_timezone(now, timezone)

    today_weekday =
      Timex.Format.DateTime.Formatters.Default.format(today, "{WDfull}")
      |> elem(1)
      |> String.downcase()
      |> String.to_atom()

    difference = @days[weekday] - @days[today_weekday]

    seconds =
      cond do
        difference > 0 -> [difference * 3600 * 24]
        difference == 0 -> [0, 7 * 3600 * 24]
        true -> [(7 - abs(difference)) * 3600 * 24]
      end

    Enum.map(seconds, fn to_add ->
      date =
        Timex.add(today, %Timex.Duration{seconds: to_add, megaseconds: 0, microseconds: 0})
        |> DateTime.to_date()
        |> Date.to_iso8601()

      datetime =
        "#{date}T#{Time.to_iso8601(time)}Z"
        |> DateTime.from_iso8601()
        |> elem(1)

      {"#{title_case(weekday)}, #{display_date(datetime)} #{display_time(datetime, timezone)}",
       datetime}
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("create_multistop.html", assigns)
  end
end
