defmodule FraytElixirWeb.LiveComponent.Pagination do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import Phoenix.HTML.Tag
  alias FraytElixirWeb.DataTable.Helpers, as: Table

  defp pagination_options(last_page) do
    0..last_page
    |> Enum.map(&{&1 + 1, &1})
  end

  defp pagination_link(icon, data_table, page, test_id) do
    disabled = data_table.filters.page == page || page < 0 || page > data_table.last_page
    class = "pagination__page" <> if disabled, do: " disabled", else: ""

    enabled_opts =
      if disabled,
        do: [],
        else: [phx_value_page: page, phx_click: Table.action(data_table, "go_to_page")]

    content_tag(
      :div,
      content_tag(:i, icon, class: "material-icons"),
      [class: class, data_test_id: test_id, tabindex: 0, onclick: ""] ++ enabled_opts
    )
  end

  def render(assigns) do
    ~L"""
    <div class="pagination <%= @container_classes %>">
      <%= pagination_link("first_page", @data_table, 0, "first-page") %>
      <%= pagination_link("keyboard_arrow_left", @data_table, @data_table.filters.page - 1, "prev-page") %>
      <div>
        <form phx-change='<%= Table.action(@data_table, "go_to_page") %>' class="select">
          <%= select :pagination, :page, pagination_options(@data_table.last_page), value: @data_table.filters.page %>
          <p class="caption u-text--center">of <%= @data_table.last_page + 1 %></p>
        </form>
      </div>
      <%= pagination_link("keyboard_arrow_right", @data_table, @data_table.filters.page + 1, "next-page") %>
      <%= pagination_link("last_page", @data_table, @data_table.last_page, "last-page") %>
    </div>
    """
  end
end
