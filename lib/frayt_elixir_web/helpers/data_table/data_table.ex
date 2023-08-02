defmodule FraytElixirWeb.DataTable do
  import Phoenix.LiveView
  alias FraytElixirWeb.DataTable

  @url_regex ~r/\{([^\}]+)\}/

  @core_filters [
    %{key: :page, type: :integer, default: 0},
    %{key: :per_page, type: :integer, default: 20},
    %{key: :order, type: :atom, default: :desc},
    %{key: :order_by, type: :atom, default: :inserted_at}
  ]

  @type basic_filter_types :: :string | :atom | :integer | :boolean
  @type filter_type :: basic_filter_types() | {:list, basic_filter_types()}
  @type order :: :asc | :desc
  @type filter_definition :: %{
          optional(:when) => atom(),
          optional(:stale) => boolean(),
          key: atom(),
          type: filter_type(),
          default: any()
        }
  @type filters :: %{
          :page => integer(),
          :per_page => integer(),
          :order => order(),
          :order_by => atom(),
          atom() => any()
        }
  @type using_opts ::
          list(
            {:filters, list(filter_definition())}
            | {:default_filters, %{atom() => any()}}
            | {:model, atom()}
            | {:base_url, String.t()}
            | {:embedded?, boolean()}
            | {:handle_filters, boolean()}
            | {:handle_params, :self | :root | :none}
            | {:init_on_mount, boolean()}
          )

  @type socket :: Phoenix.LiveView.Socket.t()

  @callback list_records(socket(), filters()) ::
              {socket(), {list(struct()), integer()}}

  @enforce_keys [:model, :base_url, :module]
  defstruct [
    :model,
    :base_url,
    :module,
    filters: %{},
    last_page: 0,
    embedded?: false,
    show_more: nil,
    updating: true,
    updating_task: nil
  ]

  @type t() :: %__MODULE__{
          filters: filters(),
          last_page: integer(),
          show_more: nil | String.t(),
          model: atom(),
          base_url: String.t(),
          module: atom(),
          updating: boolean(),
          updating_task: Task.t() | nil
        }

  @spec __using__(using_opts()) :: Macro.t()
  defmacro __using__(opts) do
    embedded? = opts[:embedded?] == true
    handle_filters = opts[:handle_filters] != false
    init_on_mount = opts[:init_on_mount] != false
    handle_params = opts[:handle_params] || :self
    filters = Macro.escape(@core_filters) ++ Keyword.get(opts, :filters, [])
    default_filters = Keyword.get(opts, :default_filters, Macro.escape(%{}))

    base_url = opts[:base_url]
    model = opts[:model] || raise(ArgumentError, "expected :model to be given as an option")
    model_name = Atom.to_string(model)

    param_events =
      case handle_params do
        p when p in [:self, :root] ->
          quote do
            if unquote(handle_params) == :self do
              use FraytElixirWeb.DataTable.Root
            end

            def maybe_push_patch(socket, default_filters, base_url) do
              %{filters: filters} = socket.assigns.data_table

              url = get_queried_url(filters, default_filters, base_url)

              if url do
                pid = get_data_table_pid(socket)

                send(pid, {:data_table, :push_patch, to: url})
              end

              socket
            end

            defp get_data_table_pid(socket) do
              if unquote(handle_params) == :self,
                do: self(),
                else: socket.root_pid
            end
          end

        :none ->
          quote do
            def maybe_push_patch(socket, _default_filters, _base_url),
              do: socket
          end
      end

    events =
      quote do
        import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

        def handle_event(
              "data_table.toggle_show_more." <> unquote(model_name) = event,
              %{"id" => item_id},
              socket
            ) do
          live_view_action(__MODULE__, event, socket, fn ->
            {:noreply,
             assign_data_table(
               socket,
               :show_more,
               toggle_show_more(socket.assigns.data_table.show_more, item_id)
             )}
          end)
        end

        def handle_event("data_table.refresh." <> unquote(model_name) = event, _event, socket) do
          live_view_action(__MODULE__, event, socket, fn ->
            {:noreply, update_results(socket)}
          end)
        end

        def handle_event(
              "data_table.sort." <> unquote(model_name) = event,
              %{"order_by" => order_by},
              socket
            ) do
          live_view_action(__MODULE__, event, socket, fn ->
            {:noreply, sort_event(socket, order_by)}
          end)
        end

        def handle_event(
              "data_table.go_to_page." <> unquote(model_name) = event,
              %{"pagination" => %{"page" => page}},
              socket
            ) do
          live_view_action(__MODULE__, event, socket, fn ->
            {:noreply, go_to_page(socket, page)}
          end)
        end

        def handle_event(
              "data_table.go_to_page." <> unquote(model_name) = event,
              %{"page" => page},
              socket
            ) do
          live_view_action(__MODULE__, event, socket, fn ->
            {:noreply, go_to_page(socket, page)}
          end)
        end
      end

    filter_events =
      if handle_filters do
        quote do
          import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

          def handle_event(
                "data_table.filter." <> unquote(model_name) = event,
                %{"filters" => filters},
                socket
              ) do
            live_view_action(__MODULE__, event, socket, fn ->
              {:noreply, filters_event(socket, filters)}
            end)
          end
        end
      end

    mounter =
      if init_on_mount do
        quote do
          def mount(params, session, %{assigns: assigns} = socket)
              when not is_map_key(assigns, :data_table) do
            socket = init_data_table(socket, params)

            mount(params, session, socket)
          end
        end
      end

    quote do
      alias FraytElixir.Convert
      import FraytElixir.AtomizeKeys
      import DataTable

      @behaviour DataTable
      @filters unquote(filters)
      @filter_keys @filters |> Enum.map(& &1.key)
      @default_filters @filters
                       |> Enum.map(fn %{key: key, default: default} -> {key, default} end)
                       |> Enum.into(%{})
                       |> Map.merge(unquote(default_filters))

      @base_url unquote(base_url)

      unquote(mounter)
      unquote(param_events)
      unquote(filter_events)
      unquote(events)

      def handle_info({ref, {:data_table, :updated, results}}, socket) do
        Process.demonitor(ref, [:flush])

        {:noreply,
         socket
         |> assign_results(results)
         |> assign_data_table(updating_task: nil)}
      end

      def init_data_table(socket, params \\ %{}) do
        params = (is_map(params) && params) || %{}

        filters = get_query_filters(params)

        socket =
          socket
          |> assign(:data_table, %DataTable{
            base_url: @base_url,
            embedded?: unquote(embedded?),
            model: unquote(model),
            module: __MODULE__
          })
          |> update_filters(filters, true)
      end

      def get_default_filters(params) do
        url_params = url_params(@base_url)

        @default_filters
        |> Enum.map(fn {key, value} ->
          if key in url_params do
            {key, Map.get(params, value)}
          else
            {key, value}
          end
        end)
        |> Enum.into(%{})
      end

      def get_query_filters(params \\ %{}) do
        filters = params |> atomize_keys()

        get_default_filters(params)
        |> Map.merge(filters)
        |> sanitize_filters()
      end

      def update_filters(socket, new_filters \\ %{}, mounting \\ false) do
        old_filters = socket.assigns.data_table.filters

        filters =
          old_filters
          |> Map.merge(new_filters)
          |> sanitize_filters()

        socket = assign_data_table(socket, :filters, filters)

        if mounting do
          socket
          |> update_results()
          |> assign(%{unquote(model) => []})
        else
          socket =
            if filters_changed?(old_filters, filters) do
              update_results(socket)
            else
              socket
            end

          maybe_push_patch(socket, @default_filters, @base_url)
        end
      end

      defp filters_changed?(old_filters, filters),
        do: filter_stale(old_filters) != filter_stale(filters)

      defp filter_stale(filters) do
        stale_keys =
          @filters
          |> Enum.filter(&Map.get(&1, :stale))
          |> Enum.map(& &1.key)

        Enum.reject(filters, fn {key, _} -> key in stale_keys end)
      end

      def update_results(socket) do
        updating_task = socket.assigns.data_table.updating_task

        if updating_task do
          Process.demonitor(updating_task.ref, [:flush])
          Task.shutdown(updating_task, :brutal_kill)
        end

        task =
          Task.async(fn ->
            {:data_table, :updated, update_results_sync(socket)}
          end)

        assign_data_table(socket, updating: true, updating_task: task)
      end

      defp update_results_sync(socket) do
        filters = socket.assigns.data_table.filters

        {socket, results, last_page} = paginate_results(socket, filters)

        {%{unquote(model) => results}, %{last_page: last_page, updating: false}}
      end

      defp assign_results(socket, {assigns, data_table_assigns}),
        do:
          socket
          |> assign(assigns)
          |> assign_data_table(data_table_assigns)

      def filters_event(socket, filters) do
        fliters = filters |> atomize_keys() |> Map.put(:page, 0)
        update_filters(socket, fliters)
      end

      def sort_event(socket, param) do
        order_by = Convert.to_atom(param)
        order = get_new_order(socket, order_by)

        update_filters(socket, %{
          page: 0,
          order: order,
          order_by: order_by
        })
      end

      def go_to_page(socket, page) do
        last_page = socket.assigns.data_table.last_page

        page = page |> Convert.to_integer() |> max(0) |> min(last_page)

        update_filters(socket, %{page: page})
      end

      def get_filter_def(key), do: @filters |> Enum.find(&(&1.key == key))

      defp assign_data_table(socket, key, value), do: assign_data_table(socket, %{key => value})

      defp assign_data_table(socket, assigns),
        do:
          socket
          |> assign(:data_table, struct(socket.assigns.data_table, assigns))

      defp sanitize_filters(filters) do
        filters =
          filters
          |> atomize_keys()
          |> Map.take(@filter_keys)
          |> Enum.map(fn {key, value} ->
            {key, convert_param(value, key)}
          end)

        filters
        |> Enum.map(fn {key, value} ->
          filter_def = get_filter_def(key)
          when_key = Map.get(filter_def, :when)
          {if_key, if_value} = Map.get(filter_def, :if) || {nil, nil}

          selected_key = filters[when_key]
          selected_value = filters[if_key]

          value =
            cond do
              is_nil(when_key) and is_nil(if_key) -> value
              selected_key == key -> value
              selected_value == if_value -> value
              true -> nil
            end

          {key, value}
        end)
        |> Enum.into(%{})
      end

      defp paginate_results(socket, %{page: page} = filters) when page < 0,
        do: paginate_results(socket, filters |> Map.put(:page, 0))

      defp paginate_results(socket, %{page: page} = filters) do
        {socket, {results, page_count}} = list_records(socket, filters)

        {socket, results, page_count - 1}
      end

      defp convert_param(value, key) do
        type =
          @filters
          |> Enum.find(&(&1.key == key))
          |> Map.get(:type)

        case type do
          :integer -> Convert.to_integer(value)
          :string -> Convert.to_string(value)
          :atom -> Convert.to_atom(value)
          :boolean -> Convert.to_boolean(value)
          :any -> Convert.value_or_nil(value)
          {:list, t} -> Convert.to_list(value, t)
        end
      end

      defp toggle_direction(:asc), do: :desc
      defp toggle_direction(:desc), do: :asc

      defp get_new_order(socket, order_by) do
        filters = socket.assigns.data_table.filters

        case Map.get(filters, :order_by) do
          ^order_by ->
            filters |> Map.get(:order, :asc) |> toggle_direction()

          _ ->
            :asc
        end
      end
    end
  end

  def get_queried_url(_filters, _default_filters, nil), do: nil

  def get_queried_url(filters, default_filters, base_url) do
    url_params = url_params(base_url)

    base_url = build_base_url(base_url, filters)

    filters
    |> Enum.reject(fn {key, value} ->
      Map.get(default_filters, key) == value or key in url_params
    end)
    |> case do
      [] -> base_url
      params -> "#{base_url}?" <> URI.encode_query(params)
    end
  end

  def toggle_show_more(former_id, current_id) when former_id == current_id, do: nil
  def toggle_show_more(_former_id, current_id), do: current_id

  def build_base_url(base_url, filters),
    do:
      Regex.replace(
        @url_regex,
        base_url,
        fn _, key ->
          key = String.to_atom(key)
          val = Map.get(filters, key)
          "#{val}"
        end,
        []
      )

  def url_params(base_url),
    do:
      Regex.scan(@url_regex, base_url, capture: :all_but_first)
      |> Enum.map(&String.to_atom(List.first(&1)))
end
