defmodule FraytElixirWeb.LiveComponent.FormulaInput do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import Phoenix.HTML.Tag
  import FraytElixirWeb.LiveViewHelpers
  alias FraytElixir.Equations

  @functions Equations.allowed_function_defs()

  def render(assigns) do
    menu_items =
      case assigns.variables do
        nil -> []
        variables -> [variables: variables]
      end ++ [functions: @functions]

    variables = Map.keys(assigns.variables)

    assigns =
      assigns
      |> Map.put(:menu_items, menu_items)
      |> Map.put(:variables, variables)

    ~L"""
      <div id="<%= @id %>">
        <%= hidden_input(@form, @field, id: @input_id) %>
        <div class="formula-input input__group">
          <%= content_tag(:code, "", [id: @input_id <> "_content", phx_hook: "FormulaInput", data: [target_input: @input_id, variables: Enum.join(@variables, ",")], class: "formula-input__input input input__area #{@class}", contenteditable: true] ++ @html_opts) %>
          <%= dropdown_menu @menu_items, [id: "#{@id}_variable_dropdown_menu", class: "input__group--addon input__group--addon--right"], fn -> %>
            <i class="fas fa-function"></i>
          <% end, fn {type, symbols} -> %>
            <span class="drop-down__menu-item-header"><%= humanize(type) %></span>
            <%= for {symbol, def} <- symbols do %>
              <a data-equation-symbol="<%= symbol_value(type, symbol) %>" class="drop-down__menu-item"><code><%= symbol %></code><%= def && " (#{def})" %></a>
            <% end %>
          <% end %>
        </div>
      </div>
    """
  end

  def symbol_value(:functions, symbol), do: "#{symbol}()"
  def symbol_value(_, symbol), do: symbol
end
