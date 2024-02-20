resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "${local.prefix}-http-api-gateway"
  description   = "HTTP API Gateway"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["*", "Content-Type", "Authorization"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "HEAD"]
    allow_origins = ["*"]
  }
}

resource "aws_lambda_permission" "allow_lambda_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*/*/*"
}

resource "aws_apigatewayv2_integration" "hello_world_integration" {
  api_id                 = aws_apigatewayv2_api.api_gateway.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "2.0"
  integration_uri        = aws_lambda_function.hello_world_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "hello_world_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world_integration.id}"
}

resource "aws_apigatewayv2_stage" "apigw_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "dev"
  auto_deploy = true
}

resource "aws_apigatewayv2_deployment" "deploy_apigw" {
  api_id = aws_apigatewayv2_api.api_gateway.id
  depends_on = [
    aws_apigatewayv2_stage.apigw_stage,
    aws_apigatewayv2_route.hello_world_route
  ]

  lifecycle {
    create_before_destroy = true
  }
}
