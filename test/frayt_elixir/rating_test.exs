defmodule FraytElixir.RatingTest do
  use FraytElixir.DataCase

  alias FraytElixir.Rating

  describe "nps" do
    setup do
      user = insert(:user)
      %{user: user}
    end

    test "create, fetch and add feedback in nps record for shipper", %{user: user} do
      user_id = user.id
      {:ok, rating} = Rating.create_nps_score(user_id, :shipper)
      nps_score = Rating.get_nps_score(rating.id)
      assert %FraytElixir.Rating.NpsScore{user_id: ^user_id} = nps_score
      Rating.add_nps_feedback(nps_score, %{score: 5, feedback: "gibberish"})

      assert %FraytElixir.Rating.NpsScore{feedback: "gibberish", score: 5} =
               Rating.get_nps_score(rating.id)
    end

    test "without nps score gives error", %{user: user} do
      user_id = user.id
      {:ok, rating} = Rating.create_nps_score(user_id, :shipper)
      nps_score = Rating.get_nps_score(rating.id)
      assert %FraytElixir.Rating.NpsScore{user_id: ^user_id} = nps_score
      response = Rating.add_nps_feedback(nps_score, %{score: nil, feedback: "gibberish"})

      assert {:error, _changeset} = response
    end

    test "without feedback gives error when score less than 5", %{user: user} do
      user_id = user.id
      {:ok, rating} = Rating.create_nps_score(user_id, :shipper)
      nps_score = Rating.get_nps_score(rating.id)
      assert %FraytElixir.Rating.NpsScore{user_id: ^user_id} = nps_score
      response = Rating.add_nps_feedback(nps_score, %{score: 2, feedback: nil})

      assert {:error, _changeset} = response
    end

    test "without nps score and feedback gives error", %{user: user} do
      user_id = user.id
      {:ok, rating} = Rating.create_nps_score(user_id, :shipper)
      nps_score = Rating.get_nps_score(rating.id)
      assert %FraytElixir.Rating.NpsScore{user_id: ^user_id} = nps_score
      response = Rating.add_nps_feedback(nps_score, %{score: nil, feedback: nil})

      assert {:error, _changeset} = response
    end
  end
end
