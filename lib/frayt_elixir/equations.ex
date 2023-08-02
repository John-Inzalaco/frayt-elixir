defmodule FraytElixir.Equations do
  import Ecto.Changeset

  @allowed_function_defs %{
    "sin" => "number",
    "cos" => "number",
    "tan" => "number",
    "round" => "number, precision = 0",
    "ceil" => "number, precision = 0",
    "floor" => "number, precision = 0"
  }
  @allowed_functions Map.keys(@allowed_function_defs)

  def allowed_function_defs, do: @allowed_function_defs
  def allowed_functions, do: @allowed_functions

  def validate_equation(changeset, field, allowed_vars) do
    validate_change(changeset, field, :empty, fn field, expression ->
      response =
        try do
          Abacus.compile(expression)
        rescue
          ArgumentError ->
            {:error, "has invalid syntax. This may be due to an incomplete decimal"}
        end

      error =
        case response do
          {:ok, _ast, vars} ->
            validate_variables(vars, allowed_vars)

          error ->
            humanize_equation_error(error)
        end

      if error do
        [{field, {error, [validation: :equation]}}]
      else
        []
      end
    end)
  end

  defp validate_variables(vars, allowed_vars) do
    case Map.keys(vars) -- (@allowed_functions ++ allowed_vars) do
      [] -> nil
      [var] -> "#{var} is not an allowed variable"
      [var | rest] -> "#{Enum.join(rest, ", ")} and #{var} are not allowed variables"
    end
  end

  defp humanize_equation_error({:error, {line, :new_parser, ['syntax error before: ', term]}}) do
    message =
      case term do
        [] ->
          "syntax error at end of line"

        [_ | _] ->
          term = List.to_string(term) |> String.replace(~r/(<<"|">>)/, "")

          "syntax error before: '#{term}'"

        _ ->
          "syntax error before: '#{term}'"
      end

    humanize_equation_error(line, message)
  end

  defp humanize_equation_error({:error, {line, :math_term, {:illegal, term}}, _}),
    do: humanize_equation_error(line, "invalid term '#{term}'")

  defp humanize_equation_error({:error, message}) when is_binary(message),
    do: message

  defp humanize_equation_error(line, message), do: message <> " on line #{line}"
end
