defmodule FraytElixir.Type.EnumHelper do
  def select_options(values, name_func, opts \\ []) do
    {allow_none, opts} = Keyword.pop(opts, :allow_none, false)
    {placeholder, opts} = Keyword.pop(opts, :placeholder, true)

    placeholder =
      if placeholder,
        do: [
          [
            key:
              if allow_none do
                allow_none || "None"
              else
                "--Select Option--"
              end,
            value: "",
            disabled: !allow_none,
            hidden: !allow_none,
            selected: true
          ]
        ],
        else: []

    placeholder ++ options(values, name_func, opts)
  end

  def options(values, name_func, opts \\ []) do
    excluded_options = Keyword.get(opts, :excluded_options, [])

    values
    |> Enum.filter(&(&1 not in excluded_options))
    |> Enum.map(&[key: name_func.(&1), value: &1])
  end
end
