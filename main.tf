terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}


resource "aws_api_gateway_account" "sns_apigw_account" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}

data "aws_iam_policy" "cloudwatch_apigw_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "${var.name}-apigw-cloudwatch-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_to_apigw"{
  role = aws_iam_role.apigw_cloudwatch_role.name
  policy_arn = data.aws_iam_policy.cloudwatch_apigw_policy.arn
}

resource "aws_api_gateway_rest_api" "sns_apigw" {
  name = "${var.name}-sms-api"
  description = "API for ${var.name} SMS application."
}
resource "aws_api_gateway_deployment" "sns_apigw_deploy" {
  depends_on = [aws_api_gateway_integration.sns_apigw_int]
  rest_api_id = aws_api_gateway_rest_api.sns_apigw.id
  description = "prod deployment"
  stage_name = "prod"
}

resource "aws_api_gateway_resource" "sns_apigw_resource" {
  parent_id = aws_api_gateway_rest_api.sns_apigw.root_resource_id
  path_part = "prod"
  rest_api_id = aws_api_gateway_rest_api.sns_apigw.id
}

resource "aws_api_gateway_method" "sns_apigw_method" {
  rest_api_id = aws_api_gateway_rest_api.sns_apigw.id
  resource_id = aws_api_gateway_resource.sns_apigw_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "sns_apigw_method_response" {
  http_method = "POST"
  resource_id = aws_api_gateway_resource.sns_apigw_resource.id
  rest_api_id = aws_api_gateway_rest_api.sns_apigw.id
  status_code = "200"
}

resource "aws_api_gateway_method_settings" "s" {
  rest_api_id = aws_api_gateway_rest_api.sns_apigw.id
  stage_name= aws_api_gateway_deployment.sns_apigw_deploy.stage_name
  method_path = "${aws_api_gateway_resource.sns_apigw_resource.path_part}/${aws_api_gateway_method.sns_apigw_method.http_method}"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
    throttling_burst_limit = 5000
    throttling_rate_limit = 10000

  }
}

resource "aws_api_gateway_integration" "sns_apigw_int" {
  rest_api_id = aws_api_gateway_rest_api.sns_apigw.id
  resource_id = aws_api_gateway_resource.sns_apigw_resource.id
  http_method = "POST"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.sns_lambda.invoke_arn
}

resource "aws_lambda_permission" "sns_api_lambda"{
  statement_id = "AllowAPIInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_lambda.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.sns_apigw.execution_arn}/*/*/*"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.name}-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "policy_for_lambda" {
  name = "${var.name}-role-policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "LogFunctionToCloudWatch",
        "Effect": "Allow",
        "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
        "Resource": "*"
      },
      {
        "Sid": "AccessSNS",
        "Effect": "Allow",
        "Action": "sns:*",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_lambda_function" "sns_lambda" {
  filename      = "notifications.zip"
  function_name = "${var.name}-sms-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "notifications.lambda_handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("notifications.zip")

  runtime = "python3.8"
}


