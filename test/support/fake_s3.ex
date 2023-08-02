defmodule FraytElixir.Test.FakeS3 do
  def s3_presigned_url(_path) do
    {:ok, "some_url"}
  end
end
