defmodule FraytElixir.Test.FakeRoutific do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(_), do: {:ok, []}

  def optimize_route_async(params) do
    job_id = :crypto.strong_rand_bytes(12) |> Base.url_encode64() |> binary_part(0, 12)

    GenServer.cast(__MODULE__, {:optimize_route_async, job_id, params})

    {:ok, %{"job_id" => job_id}}
  end

  def check_routing_status(job_id) do
    GenServer.call(__MODULE__, {:check_routing_status, job_id})
  end

  def get_job(job_id) do
    GenServer.call(__MODULE__, {:get_job, job_id})
  end

  def set_status_response(job_id, status) do
    GenServer.call(__MODULE__, {:set_response_status, job_id, status})
  end

  def handle_call({:set_response_status, job_id, status}, _from, jobs) do
    job = find_job(jobs, job_id)

    if job do
      jobs = replace_job(jobs, job_id, %{job | status_response: status})

      {:reply, :ok, jobs}
    else
      {:reply, :error, jobs}
    end
  end

  def handle_call({:get_job, job_id}, _from, jobs) do
    {:reply, find_job(jobs, job_id), jobs}
  end

  def handle_call({:check_routing_status, job_id}, _from, jobs) do
    job = find_job(jobs, job_id)

    if job do
      {status, response} = build_response(job)

      {:reply, {status, response}, replace_job(jobs, job_id, %{job | response: response})}
    else
      error = %{
        "error" => "Job kyxq7dur671s not found!",
        "error_type" => "ERR_JOB_NOT_FOUND",
        "error_vars" => %{
          "jobId" => job_id
        }
      }

      {:reply, {:error, error}, jobs}
    end
  end

  def handle_cast({:optimize_route_async, job_id, params}, jobs) do
    {:noreply,
     [
       {job_id,
        %{
          status_response: :pending,
          request: params |> Jason.encode!() |> Jason.decode!(),
          response: nil
        }}
     ] ++ jobs}
  end

  defp build_response(%{status_response: :error, request: request}),
    do:
      {:ok,
       %{
         "status" => "error",
         "input" => request,
         "output" =>
           "Sorry - we couldn't find a route for you today. Can you check your driver/stop inputs?"
       }}

  defp build_response(%{
         status_response: :finished,
         request: request
       }),
       do:
         {:ok,
          %{
            "status" => "finished",
            "input" => request,
            "output" => build_output(request)
          }}

  defp build_response(%{
         status_response: :unserved,
         request: request
       }),
       do:
         {:ok,
          %{
            "status" => "finished",
            "request" => request,
            "output" => build_output(request, 1)
          }}

  defp build_response(%{request: request}),
    do:
      {:ok,
       %{
         "status" => "pending",
         "input" => request
       }}

  defp build_output(%{"fleet" => fleet, "visits" => visits}, unserved_count \\ 0) do
    fleet_count = fleet |> Map.keys() |> length()
    visit_count = visits |> Map.keys() |> length()

    {served_v, unserved_v} = visits |> Enum.into([]) |> Enum.split(visit_count - unserved_count)

    num_served = served_v |> length()
    num_unserved = unserved_v |> length()

    solution =
      fleet
      |> Enum.with_index()
      |> Enum.map(fn {{driver_id, %{"start_location" => %{"name" => start_name}}}, index} ->
        start = %{
          "location_id" => driver_id <> "_start",
          "location_name" => start_name,
          "distance" => 0
        }

        if num_served - 1 > index && index == fleet_count - 1 do
          stops = served_v |> Enum.slice(index..num_served) |> Enum.map(&build_stop(&1))
          {driver_id, [start] ++ stops}
        else
          case Enum.at(served_v, index) do
            nil ->
              {driver_id, [start]}

            {id, visit} ->
              {driver_id, [start, build_stop({id, visit})]}
          end
        end
      end)
      |> Enum.into(%{})

    unserved =
      unserved_v
      |> Enum.map(fn {id, _} ->
        {id, "No vehicle available during the specified time windows."}
      end)
      |> Enum.into([])

    %{
      "status" => "success",
      "num_unserved" => num_unserved,
      "unserved" => (num_unserved > 0 && unserved) || nil,
      "solution" => solution
    }
  end

  defp build_stop({id, %{"location" => %{"name" => name}}}),
    do: %{"location_id" => id, "name" => name, "distance" => 3200}

  defp find_job(jobs, job_id) do
    with {_job_id, job} <- jobs |> Enum.find(&(elem(&1, 0) == job_id)) do
      job
    end
  end

  defp replace_job(jobs, job_id, job) do
    [{job_id, job}] ++ Enum.reject(jobs, &(elem(&1, 0) == job_id))
  end
end
