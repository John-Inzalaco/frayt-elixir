defmodule FraytElixirWeb.LiveViewHelpers do
  import Phoenix.LiveView.Helpers
  import Phoenix.HTML.Form
  import Phoenix.HTML.Tag

  def record_select(form, field, schema, opts \\ []) do
    args =
      Keyword.take(opts, [:value]) ++
        [
          form: form,
          field: field,
          schema: schema,
          schema_name: opts[:schema_name],
          id: opts[:id] || unique_id(form, field, "record"),
          allow_empty: Keyword.get(opts, :allow_empty, true),
          placeholder: opts[:placeholder],
          initial_record: opts[:initial_record],
          default_options: opts[:default_options] || [],
          filters: opts[:filters] || %{}
        ]

    live_component(FraytElixirWeb.LiveComponent.RecordSearchSelect, args)
  end

  def dropdown_menu(items, opts \\ [], renderer, item_renderer \\ nil) do
    {variables, opts} = Keyword.pop(opts, :variables, [])
    {functions, opts} = Keyword.pop(opts, :functions, [])

    args = [
      id: Keyword.fetch!(opts, :id),
      header: opts[:header],
      class: opts[:class],
      variables: variables,
      functions: functions,
      renderer: renderer,
      item_renderer: item_renderer,
      items: items
    ]

    live_component(FraytElixirWeb.LiveComponent.DropdownMenu, args)
  end

  def repeater_for(form, field, opts \\ [], renderer) do
    {id, opts} = Keyword.pop(opts, :id, unique_id(form, field, "repeater"))
    {class, opts} = Keyword.pop(opts, :class)
    {item_class, opts} = Keyword.pop(opts, :item_class)
    {draggable, opts} = Keyword.pop(opts, :draggable, false)
    {default, _opts} = Keyword.pop(opts, :default)

    args = [
      form: form,
      field: field,
      renderer: renderer,
      id: id,
      default: default,
      class: class,
      item_class: item_class,
      draggable: draggable
    ]

    live_component(FraytElixirWeb.LiveComponent.FormRepeater, args)
  end

  def address_input_group(form, field, opts \\ []) do
    live_component(FraytElixirWeb.LiveComponent.AddressInput,
      id: unique_id(form, field, "address_group"),
      form: form,
      field: field,
      class: opts[:class]
    )
  end

  def formula_input(form, field, opts \\ []) do
    {input_id, opts} = Keyword.pop(opts, :id, input_id(form, field))
    {class, opts} = Keyword.pop(opts, :class)
    {variables, opts} = Keyword.pop(opts, :variables)

    args = [
      form: form,
      field: field,
      id: input_id <> "_formula_input",
      input_id: input_id,
      class: class,
      variables: variables,
      html_opts: opts
    ]

    live_component(FraytElixirWeb.LiveComponent.FormulaInput, args)
  end

  def holistics_dashboard(opts) do
    {dashboard, opts} = Keyword.pop!(opts, :dashboard)
    {editing?, opts} = Keyword.pop(opts, :editing, false)
    id = dashboard.id || "new"
    editing? = if dashboard.id, do: editing?, else: true

    args = [
      id: id <> "_holistics_dashboard",
      dashboard: dashboard,
      html_opts: opts,
      editing: editing?
    ]

    live_component(FraytElixirWeb.LiveComponent.HolisticsDashboard, args)
  end

  def html_input(form, field, opts) do
    input_id = unique_id(form, field, :input)

    assigns = %{
      form: form,
      field: field,
      input_opts: Keyword.merge([id: input_id], opts),
      editor_id: unique_id(form, field, :editor),
      input_id: input_id
    }

    ~L"""
    <div class="html-input">
      <%= hidden_input @form, :content, id: @input_id %>
      <div phx-hook="HTMLInput" phx-update="ignore" data-target-input="<%= @input_id %>" id="<%= @editor_id %>">
        <%= Phoenix.HTML.raw input_value(@form, @field) %>
      </div>
    </div>
    """
  end

  def multiselect_checkboxes(form, field, options, opts \\ []) do
    {selected, _} = get_selected_values(form, field, opts)
    selected_as_strings = Enum.map(selected, &"#{&1}")

    class = opts[:class]
    label_class = opts[:label_class]
    input_class = opts[:input_class]
    disabled = opts[:disabled]

    for {value, key} <- options, into: [] do
      id = input_id(form, field, key)

      content_tag(:div, class: class) do
        [
          tag(:input,
            name: input_name(form, field) <> "[]",
            id: id,
            class: input_class,
            type: "checkbox",
            value: key,
            checked: Enum.member?(selected_as_strings, "#{key}"),
            disabled: disabled
          ),
          content_tag(:label, value, class: label_class, for: id)
        ]
      end
    end
  end

  defp get_selected_values(form, field, opts) do
    {selected, opts} = Keyword.pop(opts, :selected)
    param = field_to_string(field)

    case form do
      %{params: %{^param => sent}} ->
        {sent, opts}

      _ ->
        {selected || input_value(form, field), opts}
    end
  end

  defp field_to_string(field) when is_atom(field), do: Atom.to_string(field)
  defp field_to_string(field) when is_binary(field), do: field

  def form_name(%Phoenix.HTML.Form{name: name}), do: name
  def form_name(form) when is_atom(form), do: form

  def unique_id(form, field, suffix), do: "#{form_name(form)}_#{field}_#{suffix}"

  def go_back_link(label, path) do
    assigns = %{path: path}

    ~L"""
      <%= live_patch to: path, class: "back u-flex u-align__vertical--middle" do %>
        <i class="material-icons icon">keyboard_backspace</i><span class="u-pad__left--xxs"><%= label %></span>
      <% end %>
    """
  end
end
