# -----------------------------
# Auth Proxy Module - Simplified
# Only handles Lambda and integration
# -----------------------------

# Use existing LabRole for Lambda execution 
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# -----------------------------
# Lambda Function
# -----------------------------

# Create ZIP package for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/cognito_callback.py"
  output_path = "${path.module}/cognito_callback.zip"
}

resource "aws_secretsmanager_secret" "cognito_client_secret" {
  name = "mercado-${var.environment}-cognito-client-secret"
}

# Secrets Manager – now uses the value passed in from root
resource "aws_secretsmanager_secret_version" "cognito_client_secret_ver" {
  secret_id     = aws_secretsmanager_secret.cognito_client_secret.id
  secret_string = var.client_secret
}

resource "aws_lambda_function" "cognito_callback" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-cognito-callback"
  role            = data.aws_iam_role.lab_role.arn
  handler         = "cognito_callback.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30

  environment {
    variables = {
      CLIENT_ID         = var.client_id
      CLIENT_SECRET_ARN = aws_secretsmanager_secret.cognito_client_secret.arn
      COGNITO_DOMAIN    = "${var.cognito_domain}.auth.${var.cognito_region}.amazoncognito.com"
      CALLBACK          = "${var.api_gateway_stage_invoke_url}/callback"
      ALB_DNS           = var.alb_dns
    }
  }

  tags = var.default_tags
}

# -----------------------------
# API Gateway Integration
# -----------------------------

# Lambda integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = var.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.cognito_callback.invoke_arn
}

# Route for /callback
resource "aws_apigatewayv2_route" "callback" {
  api_id    = var.api_gateway_id
  route_key = "GET /callback"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Route for /logout
resource "aws_apigatewayv2_route" "logout" {
  api_id    = var.api_gateway_id
  route_key = "GET /logout"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# -----------------------------
# Lambda permissions
# -----------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cognito_callback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}