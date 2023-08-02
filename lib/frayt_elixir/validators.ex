defmodule FraytElixir.Validators do
  import Ecto.Changeset
  alias Ecto.Changeset
  alias ExPhoneNumber

  @date_time_validators %{
    less_than: [
      {:time, "must be before %{time}"},
      {:date, "must be before %{date}"}
    ],
    greater_than: [
      {:time, "must be after %{time}"},
      {:date, "must be after %{date}"}
    ],
    less_than_or_equal_to: [
      {:time, "must be at or before %{time}"},
      {:date, "must be on or before %{date}"}
    ],
    greater_than_or_equal_to: [
      {:time, "must be at or after %{time}"},
      {:date, "must be on or after %{date}"}
    ],
    equal_to: [
      {:time, "must be at %{time}"},
      {:date, "must be on %{date}"}
    ],
    not_equal_to: [
      {:time, "cannot be at %{time}"},
      {:date, "cannot be on %{date}"}
    ]
  }

  @valid_number_specs Map.keys(@date_time_validators)

  def assoc_when(changeset, field, conds, opts \\ []) do
    case valid_conds?(changeset, conds) do
      false ->
        put_assoc(changeset, field, nil)

      true ->
        case Map.get(changeset.params, Atom.to_string(field)) do
          value when is_struct(value) -> put_assoc(changeset, field, value)
          _ -> cast_assoc(changeset, field, opts)
        end
    end
  end

  # See https://gist.github.com/mgamini/4f3a8bc55bdcc96be2c6 for source. This should be RFC 5322 compatible
  @email_regex ~r/^[\w.!#$%&'’*+\-\/=?\^`{|}~]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$/i

  def validate_email_format(changeset, field) do
    validate_format(changeset, field, @email_regex)
  end

  def validate_assoc_length(changeset, field, opts \\ [], filterer \\ nil, meta \\ []) do
    case get_field(changeset, field) do
      nil ->
        changeset

      values ->
        values = if filterer, do: Enum.filter(values, filterer), else: values

        length_errors(changeset, field, Enum.count(values), opts, meta)
    end
  end

  defp length_errors(changeset, field, length, opts, meta) do
    error =
      (opts[:min] && length_error(:min, opts[:min], length)) ||
        (opts[:max] && length_error(:max, opts[:max], length))

    if error do
      changeset |> add_error(field, opts[:message] || elem(error, 0), elem(error, 1) ++ meta)
    else
      changeset
    end
  end

  defp length_error(:min, count, length) when is_number(count) and length < count,
    do:
      {"length should be at least %{count}", count: count, validation: :assoc_length, kind: :min}

  defp length_error(:max, count, length) when is_number(count) and length > count,
    do: {"length should be at most %{count}", count: count, validation: :assoc_length, kind: :max}

  defp length_error(_type, _count, _length), do: nil

  def validate_some_required(changeset, fields) do
    error_meta = [validation: :some_required, of: fields]

    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(
        changeset,
        hd(fields),
        "expected at least one of #{display_fields(fields)} to be present",
        error_meta
      )
    end
  end

  def validate_one_of_present(changeset, fields) do
    error_meta = [validation: :one_of_present, among: fields]

    fields
    |> Enum.filter(&present?(changeset, &1))
    |> case do
      [_] ->
        changeset

      [] ->
        add_error(
          changeset,
          hd(fields),
          "expected either #{display_fields(fields)} to be present",
          error_meta
        )

      _ ->
        add_error(
          changeset,
          hd(fields),
          "expected exactly one of #{display_fields(fields)} to be present",
          error_meta
        )
    end
  end

  def validate_number_by_field(changeset, field, opts) do
    opts =
      Enum.map(opts, fn {spec, target} ->
        case spec in @valid_number_specs and is_atom(target) do
          true -> {spec, get_field(changeset, target) |> parse_integer()}
          false -> {spec, target}
        end
      end)

    changeset
    |> validate_number(field, opts)
  end

  def validate_phone_number(changeset, field) do
    validate_change(changeset, field, fn _field, phone_number ->
      case ExPhoneNumber.is_valid_number?(phone_number) do
        true ->
          []

        _ ->
          error = "The string supplied did not seem to be a valid phone number"
          [{field, {error, [validation: :phone_number]}}]
      end
    end)
  end

  defp parse_integer(field) when is_binary(field) do
    case Integer.parse(field) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp parse_integer(field), do: field

  def validate_required_when(changeset, field, conds, opts \\ []),
    do: validate_when(changeset, field, conds, &validate_required/3, opts)

  def validate_when(changeset, field \\ nil, conds, validator, opts \\ [])

  def validate_when(changeset, nil, conds, validator, _opts) when is_list(conds) do
    case valid_conds?(changeset, conds) do
      true -> validator.(changeset)
      false -> changeset
    end
  end

  def validate_when(changeset, field, conds, validator, opts) when is_list(conds) do
    case valid_conds?(changeset, conds) do
      true -> validator.(changeset, field, opts)
      false -> changeset
    end
  end

  defp valid_conds?(changeset, conds) do
    failures =
      Enum.filter(conds, fn {target, spec, value} ->
        get_field(changeset, target)
        |> compare!(spec, value)
        |> Kernel.!()
      end)

    Enum.empty?(failures)
  end

  def validate_empty(changeset, field, opts \\ []) do
    validate_change(changeset, field, :empty, fn field, _value ->
      if present?(changeset, field) do
        [{field, {opts[:message] || "must be empty", [validation: :empty]}}]
      else
        []
      end
    end)
  end

  @type date_time_spec ::
          :less_than
          | :greater_than
          | :less_than_or_equal_to
          | :greater_than_or_equal_to
          | :equal_to
          | :not_equal_to
  @type time_opts :: list({:time_zone, String.t()} | {:message, String.t()})
  @type time_conds :: list({date_time_spec, Time.t() | nil})

  @spec validate_time(
          changeset :: Changeset.t(),
          field :: atom(),
          conds :: time_conds,
          opts :: time_opts
        ) :: Changeset.t()

  def validate_time(%Changeset{} = changeset, field, conds, opts \\ []) do
    {time_zone, opts} = Keyword.pop(opts, :time_zone, "Etc/UTC")

    opts = Keyword.put(opts, :function_name, "validate_time/4")

    time =
      case get_field(changeset, field) do
        %NaiveDateTime{} = dt -> DateTime.from_naive!(dt, "Etc/UTC") |> get_local_time(time_zone)
        %DateTime{} = dt -> get_local_time(dt, time_zone)
        %Time{} = time -> time
        nil -> nil
      end

    validate_date_or_time_rules(changeset, field, time, conds, opts ++ [validation_type: :time])
  end

  @type date_time_opts :: list({:message, String.t()})
  @type date_time_conds :: list({date_time_spec, NaiveDateTime.t() | DateTime.t() | nil})

  @spec validate_date_time(
          changeset :: Changeset.t(),
          field :: atom(),
          conds :: date_time_conds,
          opts :: date_time_opts
        ) :: Changeset.t()

  def validate_date_time(%Changeset{} = changeset, field, conds, opts \\ []) do
    opts = Keyword.put(opts, :function_name, "validate_date_time/4")

    date_time =
      case get_field(changeset, field) do
        %NaiveDateTime{} = dt -> dt
        %DateTime{} = dt -> dt
        nil -> nil
      end

    validate_date_or_time_rules(
      changeset,
      field,
      date_time,
      conds,
      opts ++ [validation_type: :date_time]
    )
  end

  defp validate_date_or_time_rules(
         changeset,
         _field,
         nil = _field_value,
         _conds,
         _opts
       ),
       do: changeset

  defp validate_date_or_time_rules(
         changeset,
         field,
         field_value,
         conds,
         opts
       ) do
    conds
    |> Enum.reject(fn {_spec, cond_value} -> is_nil(cond_value) end)
    |> Enum.reduce(changeset, &validate_date_or_time_rule(&2, field, field_value, &1, opts))
  end

  defp validate_date_or_time_rule(changeset, field, field_value, {spec, cond_value}, opts) do
    {message, opts} = Keyword.pop(opts, :message)
    {function_name, opts} = Keyword.pop(opts, :function_name)
    {validation_type, _opts} = Keyword.pop(opts, :validation_type)

    value_type = if validation_type == :date_time, do: :time, else: validation_type

    case get_default_date_time_error(spec, value_type) do
      {:ok, default_message} ->
        comparison = compare_by_validation_type(validation_type, field_value, cond_value)

        if check_date_time_spec?(comparison, spec) do
          changeset
        else
          add_error(changeset, field, message || default_message, [
            {value_type, cond_value},
            validation: validation_type,
            kind: spec
          ])
        end

      :error ->
        supported_options = Enum.map_join(@valid_number_specs, "\n", &"  * #{inspect(&1)}")

        raise ArgumentError, """
        unknown option #{inspect(spec)} given to #{function_name}
        The supported options are:
        #{supported_options}
        """
    end
  end

  defp compare_by_validation_type(validation_type, field_value, cond_value) do
    compare =
      case validation_type do
        :time ->
          &Time.compare/2

        :date_time ->
          &NaiveDateTime.compare/2
          # TODO: implement validate_date/4
          # :date -> &Date.compare/2
      end

    compare.(field_value, cond_value)
  end

  defp get_default_date_time_error(spec_key, validation_type) do
    with {:ok, message_types} <- Map.fetch(@date_time_validators, spec_key) do
      {:ok, Keyword.fetch!(message_types, validation_type)}
    end
  end

  defp check_date_time_spec?(result, spec) do
    case result do
      :gt when spec in [:greater_than, :greater_than_or_equal_to, :not_equal_to] -> true
      :lt when spec in [:less_than, :less_than_or_equal_to, :not_equal_to] -> true
      :eq when spec in [:equal_to, :greater_than_or_equal_to, :less_than_or_equal_to] -> true
      _ -> false
    end
  end

  defp get_local_time(datetime, time_zone) do
    datetime |> Timex.Timezone.convert(time_zone) |> DateTime.to_time()
  end

  def present?(changeset, field) do
    # The logic is copied from `validate_required` in Ecto.
    case get_field(changeset, field) do
      nil -> false
      binary when is_binary(binary) -> String.trim_leading(binary) != ""
      _ -> true
    end
  end

  defp display_fields(fields), do: fields |> Enum.map_join(", ", &Atom.to_string(&1))

  defp compare!(target_value, :equal_to, value)
       when is_binary(value) or is_atom(value) or is_number(value),
       do: target_value == value

  defp compare!(target_value, :not_equal_to, value)
       when is_binary(value) or is_atom(value) or is_number(value),
       do: target_value != value

  defp compare!(target_value, :greater_than, value)
       when is_number(value),
       do: target_value > value
end
