data "archive_file" "image_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/main"
  output_path = "${path.module}/lambda/main/lambda_package.zip"
}

resource "aws_lambda_function" "sagemaker_image_handler" {
  filename         = data.archive_file.sagemaker_image_handler.output_path
  function_name    = "${var.name}-sagemaker-image-handler"
  role             = aws_iam_role.sagemaker_image_handler.arn
  handler          = "main.lambda_handler"
  source_code_hash = filebase64sha256(data.archive_file.sagemaker_image_handler.output_path)
  runtime          = "python3.12"#PARAMETER
  timeout          = 30

  environment {
    variables = {
      DOMAIN_NAME = var.sagemaker_domain_id
      REPO_NAME   = aws_ecr_repository.this.name
      SM_ROLE_ARN = var.sagemaker_role_arn
      REGION      = data.aws_region.current.name
      IMAGE_TYPE  = local.image_type[var.image_type]
    }
  }

  tags = var.tags
}

resource "aws_lambda_permission" "sagemaker_image_handler_push_event" {
  function_name = aws_lambda_function.sagemaker_image_handler.function_name
  statement_id  = "AllowExecutionOnPush"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sagemaker_image_push_event.arn
}

resource "aws_lambda_permission" "sagemaker_image_handler_delete_event" {
  function_name = aws_lambda_function.sagemaker_image_handler.function_name
  statement_id  = "AllowExecutionOnDelete"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sagemaker_image_delete_event.arn
}

resource "aws_iam_role" "sagemaker_image_handler" {
  name = "${var.name}-sagemaker-image-handler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "sagemaker_image_handler" {
  name        = "${var.name}-sagemaker-image-handler"
  description = "Policy for sagemaker image handler lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sagemaker:*",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "iam:PassRole",
        Resource = var.sagemaker_role_arn
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:DescribeImages",
          "ecr:ListImages",
        ]
        Resource = aws_ecr_repository.this.arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_image_handler" {
  policy_arn = aws_iam_policy.sagemaker_image_handler.arn
  role       = aws_iam_role.sagemaker_image_handler.name
}

resource "aws_iam_role_policy_attachment" "sagemaker_image_handler_execution" {
  role       = aws_iam_role.sagemaker_image_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
