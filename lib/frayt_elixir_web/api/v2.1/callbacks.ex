defmodule FraytElixirWeb.API.V2x1.Callbacks do
  alias OpenApiSpex.{PathItem, Operation, Response, Schema}
  alias FraytElixirWeb.API.V2x1.Schemas.{BatchResponse, MatchResponse, Match}

  def batch_webhook do
    example = BatchResponse.schema().example

    %PathItem{
      post: %Operation{
        summary: "Send back Batch transitions",
        description:
          "Every time batch's state transitions an update will be sent to your configured company webhook. Updates are only sent out if webhooks are configured.",
        requestBody:
          Operation.request_body("Batch", "application/json", %Schema{
            type: :object,
            allOf: [BatchResponse],
            example:
              example
              |> Map.put(
                "response",
                Map.merge(Map.get(example, "response", %{}), %{
                  "state" => "routing_complete",
                  "matches" => [Match.schema().example]
                })
              )
          }),
        responses: %{
          200 => %Response{
            description: "Your server returns this code if it accepts the callback"
          }
        }
      }
    }
  end

  def match_webhook do
    %PathItem{
      post: %Operation{
        summary: "Send back Match transitions",
        description:
          "Every time the Match state transitions, a child stop state transitions, or the driver's location is updated when en route an update will be sent to your configured company webhook. Updates are only sent out if webhooks are configured.",
        requestBody: Operation.request_body("Match", "application/json", MatchResponse),
        responses: %{
          200 => %Response{
            description: "Your server returns this code if it accepts the callback"
          }
        }
      }
    }
  end
end
