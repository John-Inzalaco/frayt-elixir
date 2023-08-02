defmodule FraytElixir.Test.Mocks.Zapier do
  def routes(),
    do: [
      %MockMe.Route{
        name: :zapier_webhook,
        method: :post,
        path: "/zapier/hooks/catch/:key/:id",
        responses: [
          %MockMe.Response{
            flag: :success,
            body:
              Jason.encode!(%{
                "attempt" => "01887eee-0d96-cedb-2a47-cce1716d90a4",
                "id" => "01887eee-0d96-cedb-2a47-cce1716d90a4",
                "request_id" => "01887eee-0d96-cedb-2a47-cce1716d90a4",
                "status" => "success"
              })
          }
        ]
      }
    ]
end
