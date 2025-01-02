resource "aws_cloudwatch_event_rule" "image_push_event" {
  name        = "${var.name}_image_push"
  description = "EventBridge rule for capturing new image pushed to ECR event"
  event_pattern = jsonencode({
    "source" : ["aws.ecr"],
    "detail-type" : ["ECR Image Action"],
    "detail" : {
      "action-type" : ["PUSH"],
      "result" : ["SUCCESS"],
      "repository-name" : [aws_ecr_repository.this.name]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "image_push_event_target" {
  rule      = aws_cloudwatch_event_rule.image_push_event.name
  target_id = "sagemaker_image_handler_lambda"
  arn       = aws_lambda_function.this.arn
}

resource "aws_cloudwatch_event_rule" "image_delete_event" {
  name        = "${var.name}_image_delete"
  description = "EventBridge rule for capturing image deletion from ECR event"
  event_pattern = jsonencode({
    "source" : ["aws.ecr"],
    "detail-type" : ["ECR Image Action"],
    "detail" : {
      "action-type" : ["DELETE"],
      "result" : ["SUCCESS"],
      "repository-name" : [aws_ecr_repository.this.name]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "image_delete_event_target" {
  rule      = aws_cloudwatch_event_rule.image_delete_event.name
  target_id = "sagemaker_image_handler_lambda"
  arn       = aws_lambda_function.this.arn
}

