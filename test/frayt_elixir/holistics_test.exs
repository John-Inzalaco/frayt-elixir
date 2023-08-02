defmodule FraytElixir.HolisticsTest do
  alias FraytElixir.Holistics.HolisticsDashboard
  alias FraytElixir.Holistics

  use FraytElixir.DataCase

  @valid_attrs %{
    name: "Another Dashboard",
    description: "This dashboard",
    secret_key: "supersecretkey",
    embed_code: "really obv embed code"
  }

  describe "sign_embed_token" do
    test "signs embed token" do
      secret_key =
        "5bf1e8577d1357dcfe376abf915cf1aee3cc1a536b10b6502ccb9a7b47248e0d4c541db9f35e9cbcf2543cb858bffe53212f0e76cffc3800a0bdf94a369f3edb"

      assert {:ok, token, claims} = Holistics.sign_embed_token(secret_key)

      assert String.length(token) == 343

      assert %{
               "permissions" => %{"row_based" => []},
               "settings" => %{"enable_export_data" => true}
             } = claims
    end
  end

  describe "get_dashboard_embed_url" do
    test "generates a url" do
      dashboard = insert(:holistics_dashboard)

      assert {:ok, "https://us.holistics.io/embed/CODE?_token=" <> token} =
               Holistics.get_dashboard_embed_url(dashboard)

      assert String.length(token) == 343
    end
  end

  describe "get_dashboard" do
    test "gets dashboard by id" do
      %{id: did} = insert(:holistics_dashboard)

      assert %HolisticsDashboard{id: ^did} = Holistics.get_dashboard(did)
    end
  end

  describe "change_dashboard" do
    test "returns a valid changeset" do
      assert %Ecto.Changeset{changes: changes, valid?: true, errors: []} =
               Holistics.change_dashboard(%HolisticsDashboard{}, @valid_attrs)

      assert changes == @valid_attrs
    end

    test "returns a invalid changeset for missing fields" do
      assert %Ecto.Changeset{errors: errors, valid?: false} =
               Holistics.change_dashboard(%HolisticsDashboard{}, %{})

      assert [
               secret_key: {_, [validation: :required]},
               embed_code: {_, [validation: :required]},
               name: {_, [validation: :required]}
             ] = errors
    end
  end

  describe "upsert_dashboard" do
    test "inserts new dashboard" do
      assert {:ok, %HolisticsDashboard{}} =
               Holistics.upsert_dashboard(%HolisticsDashboard{}, @valid_attrs)
    end

    test "updates existing dashboard" do
      %{id: did} = dashboard = insert(:holistics_dashboard)

      assert {:ok, %HolisticsDashboard{id: ^did}} =
               Holistics.upsert_dashboard(dashboard, @valid_attrs)
    end

    test "handles invalid attrs" do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Holistics.upsert_dashboard(%HolisticsDashboard{}, %{})
    end
  end

  describe "list_dashboards" do
    test "lists all dashboards" do
      insert_list(5, :holistics_dashboard)
      assert dashboards = Holistics.list_dashboards()

      assert length(dashboards) == 5
    end
  end
end
