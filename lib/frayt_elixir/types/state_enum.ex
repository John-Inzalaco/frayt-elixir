defmodule FraytElixir.Type.StateEnum do
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Type.EnumHelper

  @type state_def :: %{
          index: integer(),
          description: String.t()
        }

  @type using_opts ::
          list(
            {:states, list(state_def())}
            | {:names, %{atom() => String.t()}}
            | {:types, list(String.t())}
          )

  @spec __using__(using_opts()) :: Macro.t()
  defmacro __using__(opts) do
    names = (opts[:names] || []) |> Enum.into(%{}) |> Macro.escape()

    quote do
      import EctoEnum

      @states unquote(opts[:states])
      @names unquote(names)
      @all_states @states |> Enum.map(fn {key, _} -> key end)
      @all_indexes @states |> Enum.map(fn {key, %{index: i}} -> {key, i} end) |> Enum.into(%{})
      @all_descriptions @states
                        |> Enum.sort_by(fn {_, %{index: i}} -> i end)
                        |> Enum.map(fn {key, %{description: d}} -> {key, d} end)

      def all_states, do: @all_states
      def all_indexes, do: @all_indexes

      def all_descriptions, do: @all_descriptions

      def render_descriptions(joiner \\ "<br/>") do
        Enum.map_join(@all_descriptions, joiner, fn {state, desc} ->
          "#{name(state)} <i>#{desc}</i>"
        end)
      end

      def render_range(range, joiner \\ " –> ")

      def render_range(:success, joiner), do: range(:success) |> render_range(joiner)

      def render_range(range, joiner) when is_list(range),
        do: range |> Enum.map_join(joiner, &name(&1))

      def range(:success), do: range(0, @all_indexes |> Map.values() |> Enum.max())

      def range(state1, state2) when is_atom(state1) and is_atom(state2),
        do: range(@all_indexes[state1], @all_indexes[state2])

      def range(index1, index2) when is_integer(index1) and is_integer(index2),
        do:
          @all_indexes
          |> Enum.filter(fn {_, i} ->
            i >= index1 && i <= index2
          end)
          |> Enum.sort_by(&elem(&1, 1))
          |> Enum.map(&elem(&1, 0))

      def name(nil), do: nil
      def name(state) when is_map_key(@names, state), do: Map.get(@names, state)

      def name(state) when is_atom(state) or is_binary(state),
        do: DisplayFunctions.title_case(state)

      def select_options(opts \\ []),
        do: EnumHelper.select_options(Map.keys(@states), &name/1, opts)

      def options, do: EnumHelper.options(Map.keys(@states), &name/1)

      def get_index(state) do
        Map.get(all_indexes(), state)
      end

      defoverridable name: 1

      defenum(
        Type,
        Enum.map(@states, fn {state, _} -> Atom.to_string(state) end) ++
          (unquote(opts[:types]) || [])
      )
    end
  end
end
