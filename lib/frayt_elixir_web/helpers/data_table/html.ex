defmodule FraytElixirWeb.DataTable.HTML do
  alias FraytElixirWeb.DataTable
  alias FraytElixirWeb.DataTable.Helpers, as: Table

  defimpl Phoenix.HTML.FormData, for: DataTable do
    def to_form(data_table, opts) do
      id = Keyword.get(opts, :id) || "dt_filter_" <> to_string(data_table.model)
      {filter_on, opts} = Keyword.pop(opts, :filter_on, :phx_change)

      %Phoenix.HTML.Form{
        source: data_table,
        impl: __MODULE__,
        id: id,
        name: :filters,
        params: %{},
        data: data_table.filters,
        errors: [],
        options: opts ++ [{filter_on, Table.action(data_table, "filter")}]
      }
    end

    def to_form(_data_table, _form, field, _opts) do
      raise ArgumentError,
            "could not generate inputs for #{inspect(field)}. inputs_for is not supported for %DataTable{}."
    end

    def input_value(_data_table, %{data: data, params: params}, field) when is_atom(field) do
      key = Atom.to_string(field)

      case params do
        %{^key => value} -> value
        %{} -> Map.get(data, field)
      end
    end

    def input_type(data_table, _form, field) do
      case data_table.module.get_filter_def(field) do
        :integer -> :number_input
        :boolean -> :checkbox
        _ -> :text_input
      end
    end

    def input_validations(_conn_or_atom, _form, _field), do: []
  end
end
