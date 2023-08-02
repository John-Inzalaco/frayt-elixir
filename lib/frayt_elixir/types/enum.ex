defmodule FraytElixir.Type.Enum do
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Type.EnumHelper

  defmacro __using__(opts) do
    names = (opts[:names] || []) |> Enum.into(%{}) |> Macro.escape()

    quote do
      import EctoEnum

      @types unquote(opts[:types])
      @names unquote(names)

      def all_types(opts \\ [])
      def all_types(string?: true), do: @types |> Enum.map(&Atom.to_string(&1))
      def all_types(_), do: @types

      def name(nil), do: nil
      def name(type) when is_map_key(@names, type), do: @names[type]
      def name(type) when is_atom(type) or is_binary(type), do: DisplayFunctions.title_case(type)

      def name(types, joiner \\ ", ") when is_list(types),
        do: types |> Enum.map_join(joiner, &DisplayFunctions.title_case(&1))

      def select_options(opts \\ []), do: EnumHelper.select_options(@types, &name/1, opts)

      def options(opts \\ []), do: EnumHelper.options(@types, &name/1, opts)

      defoverridable name: 1

      defenum(
        Type,
        @types |> Enum.map(fn state -> Atom.to_string(state) end)
      )
    end
  end
end
