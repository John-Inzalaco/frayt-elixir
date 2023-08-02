defmodule FraytElixir.Repo.MonthlyMigrations.CreateSentNotificationsPartition do
  use Ecto.Migration
  import FraytElixir.Helpers.TablePartitioning

  def up do
    this_month = DateTime.utc_now() |> DateTime.to_date() |> Timex.set(day: 1)
    next_month = Timex.shift(this_month, months: 1)

    create_partition(:sent_notifications, this_month, if_not_exists: true)
    create_partition(:sent_notifications, next_month, if_not_exists: true)
  end

  def down do
    # recurring migrations do not revert data on down
  end
end
