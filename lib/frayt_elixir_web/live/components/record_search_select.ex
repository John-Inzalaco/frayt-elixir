defmodule FraytElixirWeb.LiveComponent.RecordSearchSelect do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import FraytElixirWeb.{DisplayFunctions, LiveViewHelpers}

  alias FraytElixir.RecordSearch

  def mount(socket) do
    {:ok,
     assign(socket, %{
       selected_record: nil,
       input_value: "",
       placeholder: nil,
       schema_name: nil,
       options: [],
       filters: %{},
       init: false,
       allow_empty: false,
       default_options: []
     })}
  end

  def update(assigns, socket) do
    %{default_options: default_options} = assigns

    assigns =
      if socket.assigns.init do
        assigns
      else
        assigns = assign_select_options(assigns)

        options = Map.get(assigns, :options, [])

        assigns
        |> Map.put(:options, Enum.uniq_by(options ++ default_options, & &1.id))
        |> Map.put(:init, true)
      end

    {:ok, assign(socket, assigns)}
  end

  defp assign_select_options(assigns) do
    %{form: form, field: field, initial_record: initial_record, default_options: default_options} =
      assigns

    record_id = Map.get(assigns, :value, input_value(form, field))

    cond do
      not is_nil(initial_record) ->
        assigns
        |> Map.put(:selected_record, initial_record)
        |> Map.put(:options, [initial_record])

      not is_nil(record_id) ->
        struct = struct(assigns.schema, id: record_id)

        record =
          Enum.find(default_options, &(&1.id == record_id)) ||
            RecordSearch.get_record(struct)

        case record do
          nil ->
            assigns

          record ->
            assigns
            |> Map.put(:selected_record, record)
            |> Map.put(:options, [record])
        end

      true ->
        assigns
    end
  end

  def handle_event(
        "query_changed",
        %{"value" => value},
        %{
          assigns: %{
            input_value: current_value,
            options: options,
            default_options: default_options
          }
        } = socket
      ) do
    options =
      case value do
        "" -> default_options
        ^current_value -> options
        value -> list_records(socket, value)
      end

    {:noreply, assign(socket, %{input_value: value, options: options})}
  end

  def handle_event(
        "select_record",
        %{"record_id" => record_id},
        %{
          assigns: %{
            options: options
          }
        } = socket
      ) do
    selected_record = Enum.find(options, fn record -> record.id == record_id end)

    {:noreply,
     assign(socket, %{
       selected_record: selected_record,
       input_value: ""
     })}
  end

  def render(assigns) do
    schema_name = display_schema(assigns.schema_name, assigns.schema)

    empty_label =
      assigns.placeholder ||
        if assigns.allow_empty, do: "All #{schema_name}(s)", else: "Select #{schema_name}"

    assigns =
      assigns
      |> Map.put(:schema_name, schema_name)
      |> Map.put(:empty_label, empty_label)

    ~L"""
      <div class="record-search">
        <input class="record-search__input" id="<%= @id %>" name="record_search_<%= form_name(@form) %>_<%= @field %>" value="<%= @input_value %>" phx-keyup="query_changed" phx-target="<%= @myself %>" phx-debounce="500"/>
        <ul class="record-search__results">
          <%= if length(@options) > 0 do %>
            <%= for record <- @options do %>
              <li class='<%= get_selected_class(@selected_record, record) %>'>
                <a onclick="" tabindex=0 id="<%= @id %>_<%= record.id %>" phx-click="select_record" phx-target="<%= @myself %>" phx-value-record_id="<%= record.id %>"><%= display_record(record) %></a>
              </li>
            <% end %>
          <% end %>
          <%= if @allow_empty do %>
            <li class='<%= get_selected_class(@selected_record, nil) %>'><a onclick="" tabindex=0 id="<%= @id %>_empty" phx-click="select_record" phx-target="<%= @myself %>" phx-value-record_id=""><%= empty_label %></a></li>
          <% end %>
          <%= if length(@options) == 0 do %>
            <%= if @input_value == "" do %>
              <li class="disabled"><span>Start typing find a <%= @schema_name %></span></li>
            <% else %>
              <li class="disabled"><span>No <%= @schema_name %>(s) found</span></li>
            <% end %>
          <% end %>
        </ul>
        <label for="<%= @id %>" class="record-search__selected"><%= display_record(@selected_record, @empty_label) %></label>

        <%= hidden_input @form, @field, value: get_record_id(@selected_record), phx_hook: "TriggerChange" %>
      </div>
    """
  end

  defp get_selected_class(selected_record, record) do
    if get_record_id(selected_record) == get_record_id(record),
      do: "record-search__selected-option"
  end

  defp list_records(%{assigns: %{schema: schema, filters: filters}}, query) do
    filters = filters |> Map.put(:query, query)
    record = struct(schema)

    {records, _page_count} = RecordSearch.list_records(record, filters)

    records
  end

  defp get_record_id(%{id: id}), do: id
  defp get_record_id(_), do: nil

  defp display_schema(nil, schema),
    do:
      schema
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()
      |> String.split(~r/(?=[A-Z])/)
      |> Enum.join(" ")
      |> title_case()

  defp display_schema(schema_name, _),
    do: schema_name

  defp display_record(record, placeholder \\ nil)
  defp display_record(nil, nil), do: ""
  defp display_record(nil, placeholder), do: placeholder
  defp display_record(record, _), do: RecordSearch.display_record(record)
end
