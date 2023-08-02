defmodule FraytElixirWeb.FormHelpers do
  import Phoenix.HTML.Tag
  import Phoenix.HTML.Form
  alias ExPhoneNumber.Model.PhoneNumber
  alias FraytElixir.Convert

  def phone_number_input(form, field, opts \\ []) do
    value = opts[:value] || phone_value(form, field)
    text_input(form, field, opts ++ [value: value])
  end

  defp phone_value(form, field) do
    case input_value(form, field) do
      %PhoneNumber{} = phone -> ExPhoneNumber.format(phone, :e164)
      value -> value
    end
  end

  def radio_select(form, field, options, opts \\ [], radio_opts \\ []) do
    {selected, opts} = Keyword.pop(opts, :value, input_value(form, field))
    {radio_class, radio_opts} = Keyword.pop(radio_opts, :class)

    content_tag :div, opts do
      options
      |> Enum.map(fn opts ->
        key = Keyword.get(opts, :key)
        value = Keyword.get(opts, :value)
        id = input_id(form, field, value)

        content_tag :div, class: radio_class do
          [
            tag(
              :input,
              radio_opts
              |> Keyword.merge(
                name: input_name(form, field),
                id: id,
                type: "radio",
                value: value,
                checked: Convert.to_string(value) == Convert.to_string(selected)
              )
            ),
            content_tag(:label, key, for: id)
          ]
        end
      end)
    end
  end

  def checkbox_select(form, field, options, opts \\ [], checkbox_opts \\ []) do
    {selected, opts} = Keyword.pop(opts, :selected, input_value(form, field))

    selected =
      if selected do
        Enum.map(selected, &Convert.to_string(&1))
      else
        []
      end

    content_tag :div, opts do
      inputs =
        options
        |> Enum.map(fn opts ->
          key = Keyword.get(opts, :key)
          value = Keyword.get(opts, :value)
          id = input_id(form, field, value)

          checkbox_opts =
            checkbox_opts
            |> Keyword.merge(
              name: input_name(form, field) <> "[]",
              id: id,
              type: "checkbox",
              value: value,
              checked: Enum.member?(selected, "#{value}")
            )

          content_tag :div, class: "checkbox checkbox--horizontal" do
            [
              tag(:input, checkbox_opts),
              content_tag(:label, key, for: id)
            ]
          end
        end)

      fallback_input =
        tag(:input, name: input_name(form, field) <> "[]", value: "", type: "hidden")

      [fallback_input, inputs]
    end
  end

  def is_checked(form, field), do: input_value(form, field) in [true, "true"]
end
