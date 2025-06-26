# CloudWatch EventBridge rule to trigger daily at midnight UTC
resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "daily-scraper-trigger"
  description         = "Trigger the scraper lambda every day"
  schedule_expression = "cron(0 0 * * ? *)"
}

# Connect EventBridge to Lambda
resource "aws_cloudwatch_event_target" "scraper_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_schedule.name
  target_id = "scraperLambda"
  arn       = aws_lambda_function.scraper_lambda.arn
}

# Grant EventBridge permission to trigger the Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scraper_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule.arn
}

# Variables
variable "lambda_root" {
  type        = string
  description = "The relative path to the source of the lambda"
  default     = "../lambda"
}

variable "lambda_subnet_ids" {
  description = "The subnet IDs for the Lambda function"
  type        = list(string)
}

variable "lambda_security_group_ids" {
  description = "The security group IDs for the Lambda function"
  type        = list(string)
}



# Install dependencies locally into the lambda folder using a Linux Docker container
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
  command = "docker run --rm -v ${abspath(var.lambda_root)}:/lambda -w /lambda python:3.12-slim sh install.sh"
  }


  triggers = {
    requirements_hash = filemd5("${var.lambda_root}/requirements.txt")
    main_hash         = filemd5("${var.lambda_root}/main.py")
    install_hash      = filemd5("${var.lambda_root}/install.sh")
  }
}


data "archive_file" "lambda_source" {
  depends_on  = [null_resource.install_dependencies]
  type        = "zip"
  source_dir  = "${var.lambda_root}/build"
  output_path = "${path.module}/${random_uuid.lambda_src_hash.result}.zip"
}


# Generate unique hash for archive updates
resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(var.lambda_root, "main.py"),
      fileset(var.lambda_root, "requirements.txt")
    ) :
    filename => filemd5("${var.lambda_root}/${filename}")
  }
}



# IAM Role (assumes LabRole exists if using AWS Learner Labs)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# CloudWatch log group (adjust name if needed)
resource "aws_cloudwatch_log_group" "task_creation" {
  name              = "/aws/lambda/trigger_scraper"
  retention_in_days = 14
}

# Lambda deployment
resource "aws_lambda_function" "scraper_lambda" {
  function_name    = "trigger_scraper"
  role             = data.aws_iam_role.lab_role.arn
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256

  handler = "main.lambda_handler"
  runtime = "python3.12"
  timeout = 60
  environment {
    variables = {
      SQS_QUEUE_URL = var.sqs_queue_url
      SQS_REGION    = var.sqs_region
      DATABASE_URL  = var.database_url
    }
  }

  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = var.lambda_security_group_ids
  }

  depends_on = [
    aws_cloudwatch_log_group.task_creation
  ]
}
