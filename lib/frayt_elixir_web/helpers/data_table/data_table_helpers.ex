defmodule FraytElixirWeb.DataTable.Helpers do
  import Phoenix.LiveView.Helpers
  import Phoenix.HTML.Tag
  alias FraytElixirWeb.DataTable

  @type element_opt :: {:class, String.t()}
  @type component_opt :: {:id, String.t()} | element_opt()

  @spec details_path(DataTable.t(), String.t()) :: String.t()
  def details_path(
        %DataTable{
          base_url: base_url,
          embedded?: embedded,
          filters: filters,
          model: model
        },
        id
      ) do
    base_url = DataTable.build_base_url(base_url, filters)

    if embedded do
      "#{base_url}/#{model}/#{id}"
    else
      "#{base_url}/#{id}"
    end
  end

  @spec sort_header(DataTable.t(), String.t(), atom(), list(element_opt())) ::
          Phoenix.HTML.safe()
  def sort_header(
        %DataTable{filters: %{order: order, order_by: order_by}, model: model} = data_table,
        label,
        field,
        opts \\ []
      ) do
    assigns = %{
      field: field,
      order_by: order_by,
      order: order,
      label: label,
      model: model,
      action: action(data_table, "sort"),
      class: opts[:class]
    }

    ~L"""
      <th class="sort <%= @class %>" tabindex=0 phx-click="<%= @action %>" phx-value-order_by="<%= @field %>" data-test-id="sort-by-<%= @field %>">
        <%= @label %>
        <%= if @order_by == @field do %>
          <i class="material-icons sort__arrow u-align__vertical--middle"><%= display_arrows(@order) %></i>
        <% end %>
      </th>
    """
  end

  @spec pagination_nav(DataTable.t(), list(component_opt())) :: Phoenix.LiveView.Component.t()
  def pagination_nav(data_table, opts \\ []),
    do:
      live_component(FraytElixirWeb.LiveComponent.Pagination,
        id: component_id(data_table, "pagination", opts[:id]),
        data_table: data_table,
        container_classes: opts[:class]
      )

  @spec show_more_button(FraytElixirWeb.DataTable.t(), String.t(), atom(), keyword(), (() -> any)) ::
          Phoenix.HTML.safe()

  def show_more_button(data_table, id, tag \\ :button, opts \\ [], fun) when is_atom(tag) do
    {class, opts} = Keyword.pop(opts, :class)
    {active_class, opts} = Keyword.pop(opts, :active_class)
    show_more? = show_more?(data_table, id)

    opts =
      opts ++
        [
          class: "data-table__show-more #{class} #{if show_more?, do: active_class}",
          phx_click: action(data_table, "toggle_show_more"),
          phx_value_id: id,
          onclick: "",
          tabindex: 0
        ]

    content_tag(tag, fun.(), opts)
  end

  @spec refresh_button(DataTable.t(), list(component_opt() | {:icon, String.t()})) ::
          Phoenix.HTML.safe()
  def refresh_button(data_table, opts \\ []) do
    icon = opts[:icon] || "sync"

    class =
      "data-table__refresh #{opts[:class]} #{if data_table.updating, do: "data-table__refresh--updating"}"

    content_tag(:button, content_tag(:i, icon, class: "material-icons icon"),
      class: class,
      tabindex: 0,
      disabled: data_table.updating,
      phx_click: action(data_table, "refresh")
    )
  end

  @spec action(DataTable.t(), String.t()) :: String.t()
  def action(data_table, name), do: "data_table.#{name}.#{data_table.model}"

  @spec show_more?(DataTable.t(), String.t()) :: boolean()
  def show_more?(data_table, id), do: data_table.show_more == id

  defp component_id(data_table, name, id) do
    action(data_table, name) <> if id, do: ".#{id}", else: ""
  end

  defp display_arrows(order) when order == :desc, do: "arrow_downward"
  defp display_arrows(order) when order == :asc, do: "arrow_upward"
end
