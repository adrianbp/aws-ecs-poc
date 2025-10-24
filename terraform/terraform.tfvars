project_name               = "ecs-demo"
environment                = "dev"
region                     = "us-east-1"
desired_count              = 1
container_image            = "389985004788.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-dev-service:latest"
jvm_tool_options           = "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"
github_owner               = "adrianbp"
github_repository          = "aws-ecs-poc"
github_branch              = "main"
enable_datadog_agent       = true
datadog_api_key_secret_arn = null
datadog_site               = "us5.datadoghq.com"
datadog_apm_enabled        = true
datadog_logs_enabled       = true
datadog_tags               = "service:ecs-demo,env:dev"
