defmodule FraytElixir.Workers.MonthlyMigrations do
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 5

  alias FraytElixir.Notifications.Slack

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: attempt, max_attempts: max_attempts})
      when attempt > 2 do
    Slack.send_message(
      :appsignal,
      "Warning! Recurring migrations are on attempt ##{attempt}. #{max_attempts - attempt} attempts remaining"
    )

    run_migrations()
  end

  def perform(_job) do
    run_migrations()
  end

  def run_migrations do
    repo = FraytElixir.Repo

    path = Ecto.Migrator.migrations_path(repo, "monthly_migrations")

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, path, :up, all: true))
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, path, :down, all: true))
  end
end
