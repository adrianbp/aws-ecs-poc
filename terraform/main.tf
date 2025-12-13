provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  subnet_config       = { for idx, az in var.availability_zones : az => var.public_subnet_cidrs[idx] }
  github_subject      = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/${var.github_branch}"
  native_service_name = "${local.name_prefix}-native"
  native_dd_service   = coalesce(var.native_dd_service_name, "${var.project_name}-native")
  otel_service_name   = "${local.name_prefix}-otel"

  app_environment = concat(
    [
      {
        name  = "JAVA_TOOL_OPTIONS"
        value = var.jvm_tool_options
      }
    ],
    var.enable_datadog_agent ? [
      {
        name  = "DD_AGENT_HOST"
        value = "127.0.0.1"
      },
      {
        name  = "DD_ENV"
        value = var.environment
      },
      {
        name  = "DD_SERVICE"
        value = var.project_name
      },
      {
        name  = "DD_TRACE_AGENT_URL"
        value = "unix:///var/run/datadog/apm.socket"
      }
    ] : []
  )

  app_container_definition = merge(
    {
      name      = "app"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = local.app_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.region
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = "${local.name_prefix}"
        }
      }
    },
    var.enable_datadog_agent
    ? {
      entryPoint = ["sh", "-c"]
      command = [
        "export DD_AGENT_HOST=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4); exec java -javaagent:${var.datadog_java_agent_path} $JAVA_TOOL_OPTIONS -jar app.jar"
      ]
    }
    : {
      entryPoint = ["sh", "-c"]
      command    = ["exec java $JAVA_TOOL_OPTIONS -jar app.jar"]
    },
    var.enable_datadog_agent ? {
      mountPoints = [
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
        }
      ]
    } : {}
  )

  datadog_environment = var.enable_datadog_agent ? concat(
    [
      {
        name  = "DD_SITE"
        value = var.datadog_site
      },
      {
        name  = "ECS_FARGATE"
        value = "true"
      },
      {
        name  = "DD_APM_ENABLED"
        value = var.datadog_apm_enabled ? "true" : "false"
      },
      {
        name  = "DD_LOGS_ENABLED"
        value = var.datadog_logs_enabled ? "true" : "false"
      }
    ],
    var.datadog_tags == null
    ? []
    : [
      {
        name  = "DD_TAGS"
        value = var.datadog_tags
      }
    ]
  ) : []

  datadog_secret_arn_primary = var.enable_datadog_agent ? coalesce(
    var.datadog_api_key_secret_arn,
    try(aws_secretsmanager_secret.datadog[0].arn, null)
  ) : null

  datadog_container_definition = var.enable_datadog_agent ? merge(
    {
      name              = "datadog-agent"
      image             = var.datadog_agent_image
      essential         = false
      cpu               = 64
      memoryReservation = 256
      environment       = local.datadog_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.region
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = "${local.name_prefix}-datadog"
        }
      }
    },
    local.datadog_secret_arn_primary == null
    ? {}
    : {
      secrets = [
        {
          name      = "DD_API_KEY"
          valueFrom = local.datadog_secret_arn_primary
        }
      ]
    },
    {
      mountPoints = [
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
        }
      ]
    }
  ) : null

  native_app_environment = var.native_service_enabled && var.enable_datadog_agent ? [
    {
      name  = "DD_AGENT_HOST"
      value = "127.0.0.1"
    },
    {
      name  = "DD_ENV"
      value = var.environment
    },
    {
      name  = "DD_SERVICE"
      value = local.native_dd_service
    },
    {
      name  = "DD_TRACE_AGENT_URL"
      value = "unix:///var/run/datadog/apm.socket"
    },
    {
      name  = "DD_TRACE_ENABLED"
      value = "true"
    },
    {
      name  = "DD_PROFILING_ENABLED"
      value = "true"
    },
    {
      name  = "DD_NATIVE_RUNTIME"
      value = "graalvm"
    }
  ] : []

  native_app_container_definition = var.native_service_enabled ? merge(
    {
      name      = "app-native"
      image     = coalesce(var.native_container_image, var.container_image)
      essential = true
      portMappings = [
        {
          containerPort = var.native_container_port
          hostPort      = var.native_container_port
          protocol      = "tcp"
        }
      ]
      environment = local.native_app_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.region
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = "${local.native_service_name}"
        }
      }
    },
    var.enable_datadog_agent ? {
      mountPoints = [
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
        }
      ]
    } : {}
  ) : null

  native_datadog_container_definition = var.native_service_enabled && var.enable_datadog_agent ? merge(
    {
      name              = "datadog-agent-native"
      image             = var.datadog_agent_image
      essential         = false
      cpu               = 64
      memoryReservation = 256
      environment       = local.datadog_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.region
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = "${local.native_service_name}-datadog"
        }
      }
    },
    local.datadog_secret_arn_primary == null
    ? {}
    : {
      secrets = [
        {
          name      = "DD_API_KEY"
          valueFrom = local.datadog_secret_arn_primary
        }
      ]
    },
    {
      mountPoints = [
        {
          containerPath = "/var/run/datadog"
          sourceVolume  = "dd-sockets"
        }
      ]
    }
  ) : null

  otel_app_environment = [
    for env in [
      {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = var.otel_exporter_otlp_protocol
      },
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = var.otel_exporter_otlp_endpoint
      },
      {
        name  = "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"
        value = var.otel_exporter_otlp_metrics_temporality_preference
      },
      {
        name  = "OTEL_RESOURCE_ATTRIBUTES"
        value = var.otel_resource_attributes
      }
    ] : env if try(env.value, null) != null && try(env.value, "") != ""
  ]

  otel_app_secrets = var.otel_exporter_otlp_headers_secret_arn == null ? [] : [
    {
      name      = "OTEL_EXPORTER_OTLP_HEADERS"
      valueFrom = var.otel_exporter_otlp_headers_secret_arn
    }
  ]

  otel_app_container_definition = var.otel_service_enabled ? merge(
    {
      name      = "app-otel"
      image     = var.otel_container_image
      essential = true
      portMappings = [
        {
          containerPort = var.otel_container_port
          hostPort      = var.otel_container_port
          protocol      = "tcp"
        }
      ]
      environment = local.otel_app_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.region
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = "${local.otel_service_name}"
        }
      }
    },
    length(local.otel_app_secrets) > 0 ? { secrets = local.otel_app_secrets } : {}
  ) : null

  otel_container_definitions_list = [for c in [local.otel_app_container_definition] : c if c != null]
  otel_container_definitions_json = jsonencode(local.otel_container_definitions_list)

  otel_secret_arn = var.otel_service_enabled ? var.otel_exporter_otlp_headers_secret_arn : null
  otel_secret_arns = local.otel_secret_arn == null ? [] : [
    local.otel_secret_arn,
    "${local.otel_secret_arn}:*",
    "${local.otel_secret_arn}-*"
  ]

  dynatrace_service_name = "${local.name_prefix}-dynatrace"

  dynatrace_app_environment = [
    {
      name  = "JAVA_TOOL_OPTIONS"
      value = var.jvm_tool_options
    }
  ]

  dynatrace_app_container_definition = var.dynatrace_service_enabled ? {
    name      = "app-dynatrace"
    image     = coalesce(var.dynatrace_container_image, var.container_image)
    essential = true
    portMappings = [
      {
        containerPort = var.dynatrace_container_port
        hostPort      = var.dynatrace_container_port
        protocol      = "tcp"
      }
    ]
    environment = local.dynatrace_app_environment
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-region        = var.region
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-stream-prefix = "${local.dynatrace_service_name}"
      }
    }
    dependsOn = [
      {
        containerName = "dynatrace-oneagent"
        condition     = "START"
      }
    ]
  } : null

  dynatrace_secret_arn = var.dynatrace_service_enabled ? var.dynatrace_api_token_secret_arn : null

  dynatrace_oneagent_environment = var.dynatrace_service_enabled ? [
    for env in [
      {
        name  = "ONEAGENT_ENVIRONMENTID"
        value = var.dynatrace_tenant_id
      },
      {
        name  = "ONEAGENT_APIURL"
        value = var.dynatrace_api_url
      }
    ] : env if try(env.value, null) != null && try(env.value, "") != ""
  ] : []

  dynatrace_oneagent_container_definition = var.dynatrace_service_enabled ? merge(
    {
      name        = "dynatrace-oneagent"
      image       = var.dynatrace_oneagent_image
      essential   = false
      environment = local.dynatrace_oneagent_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.region
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = "${local.dynatrace_service_name}-oneagent"
        }
      }
    },
    local.dynatrace_secret_arn == null ? {} : {
      secrets = [
        {
          name      = "ONEAGENT_APITOKEN"
          valueFrom = local.dynatrace_secret_arn
        }
      ]
    }
  ) : null

  dynatrace_container_definitions_list = [for c in [local.dynatrace_app_container_definition, local.dynatrace_oneagent_container_definition] : c if c != null]
  dynatrace_container_definitions_json = jsonencode(local.dynatrace_container_definitions_list)

  dynatrace_secret_arns = local.dynatrace_secret_arn == null ? [] : [
    local.dynatrace_secret_arn,
    "${local.dynatrace_secret_arn}:*",
    "${local.dynatrace_secret_arn}-*"
  ]

  container_definitions_list = [for c in [local.app_container_definition, local.datadog_container_definition] : c if c != null]
  container_definitions_json = jsonencode(local.container_definitions_list)

  native_container_definitions_list = [for c in [local.native_app_container_definition, local.native_datadog_container_definition] : c if c != null]
  native_container_definitions_json = jsonencode(local.native_container_definitions_list)

  datadog_volumes = var.enable_datadog_agent ? ["dd-sockets"] : []
  datadog_secret_arns = var.enable_datadog_agent ? distinct(
    compact(
      concat(
        local.datadog_secret_arn_primary != null ? [
          local.datadog_secret_arn_primary,
          "${local.datadog_secret_arn_primary}:*",
          "${local.datadog_secret_arn_primary}-*"
        ] : [],
        var.datadog_api_key_secret_arn != null && local.datadog_secret_arn_primary != var.datadog_api_key_secret_arn ? [
          var.datadog_api_key_secret_arn,
          "${var.datadog_api_key_secret_arn}:*",
          "${var.datadog_api_key_secret_arn}-*"
        ] : []
      )
    )
  ) : []
  datadog_ssm_parameter_arns = var.enable_datadog_agent ? [
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/*"
  ] : []

  ecs_task_allowed_ports = distinct(concat([
    var.container_port
    ],
    var.native_service_enabled ? [var.native_container_port] : [],
    var.dynatrace_service_enabled ? [var.dynatrace_container_port] : [],
  var.otel_service_enabled ? [var.otel_container_port] : []))

  github_secret_describe_arns = distinct(concat(local.datadog_secret_arns, local.dynatrace_secret_arns, local.otel_secret_arns))

  codebuild_project_name = coalesce(var.codebuild_project_name, "${local.name_prefix}-codebuild-sb4-otel")
}

resource "aws_cloudwatch_log_group" "codebuild" {
  count             = var.codebuild_enabled ? 1 : 0
  name              = "/aws/codebuild/${local.codebuild_project_name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "codebuild_assume" {
  count = var.codebuild_enabled && var.codebuild_service_role_arn == null ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild" {
  count = var.codebuild_enabled && var.codebuild_service_role_arn == null ? 1 : 0

  name               = "${local.name_prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume[0].json
}

resource "aws_iam_role_policy_attachment" "codebuild_managed" {
  count      = var.codebuild_enabled && var.codebuild_service_role_arn == null ? 1 : 0
  role       = aws_iam_role.codebuild[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy" "codebuild_logs" {
  count = var.codebuild_enabled && var.codebuild_service_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-codebuild-logs"
  role = aws_iam_role.codebuild[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.codebuild_project_name}:*"
        ]
      }
    ]
  })
}

locals {
  codebuild_role_arn = var.codebuild_enabled ? coalesce(var.codebuild_service_role_arn, try(aws_iam_role.codebuild[0].arn, null)) : null
}

resource "aws_codebuild_project" "springboot4_otel" {
  count        = var.codebuild_enabled ? 1 : 0
  name         = local.codebuild_project_name
  description  = "Native build for Spring Boot 4 OTEL POC"
  service_role = local.codebuild_role_arn
  build_timeout = var.codebuild_timeout

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = var.codebuild_privileged_mode
    image_pull_credentials_type = "CODEBUILD"

    dynamic "environment_variable" {
      for_each = var.codebuild_environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
        type  = "PLAINTEXT"
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild[0].name
      stream_name = "build"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_owner}/${var.github_repository}.git"
    git_clone_depth = 1
    buildspec       = var.codebuild_buildspec
  }

  source_version = var.github_branch

  tags = {
    Name        = local.codebuild_project_name
    Environment = var.environment
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.subnet_config

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Permite trafego HTTP para o ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Permite trafego do ALB para as tasks ECS"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = toset(local.ecs_task_allowed_ports)
    content {
      description     = "Trafego do ALB"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-sg"
  }
}

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

resource "aws_lb_target_group" "native" {
  count       = var.native_service_enabled ? 1 : 0
  name        = "${local.native_service_name}-tg"
  port        = var.native_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = var.native_health_check_path
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "${local.native_service_name}-tg"
  }
}

resource "aws_lb_target_group" "dynatrace" {
  count       = var.dynatrace_service_enabled ? 1 : 0
  name        = "${local.dynatrace_service_name}-tg"
  port        = var.dynatrace_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = var.dynatrace_health_check_path
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "${local.dynatrace_service_name}-tg"
  }
}

resource "aws_lb_target_group" "otel" {
  count       = var.otel_service_enabled ? 1 : 0
  name        = "${local.otel_service_name}-tg"
  port        = var.otel_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = var.otel_health_check_path
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "${local.otel_service_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener_rule" "native" {
  count        = var.native_service_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.native[0].arn
  }

  condition {
    path_pattern {
      values = ["/native", "/native/*", "/native*"]
    }
  }
}

resource "aws_lb_listener_rule" "dynatrace" {
  count        = var.dynatrace_service_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dynatrace[0].arn
  }

  condition {
    path_pattern {
      values = ["/dynatrace", "/dynatrace/*", "/dynatrace*"]
    }
  }
}

resource "aws_lb_listener_rule" "otel" {
  count        = var.otel_service_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.otel[0].arn
  }

  condition {
    path_pattern {
      values = ["/otel", "/otel/*", "/otel*"]
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecr_repository" "this" {
  name                 = "${local.name_prefix}-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "native" {
  count                = var.native_service_enabled ? 1 : 0
  name                 = "${local.name_prefix}-native"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "dynatrace" {
  count                = var.dynatrace_service_enabled ? 1 : 0
  name                 = "${local.name_prefix}-dynatrace"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "otel" {
  count                = var.otel_service_enabled ? 1 : 0
  name                 = local.otel_service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_secretsmanager_secret" "datadog" {
  count = var.enable_datadog_agent && var.datadog_api_key_secret_arn == null ? 1 : 0

  name = "${local.name_prefix}-datadog-api-key"

  tags = {
    Name        = "${local.name_prefix}-datadog-api-key"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "datadog" {
  count = var.enable_datadog_agent && var.datadog_api_key_secret_arn == null ? 1 : 0

  secret_id     = aws_secretsmanager_secret.datadog[0].id
  secret_string = var.datadog_api_key_value

  lifecycle {
    precondition {
      condition     = var.datadog_api_key_value != null && var.datadog_api_key_value != ""
      error_message = "Informe datadog_api_key_value quando enable_datadog_agent for true e nenhum ARN de secret for fornecido."
    }

    ignore_changes = [secret_string]
  }
}

data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_cloudwatch" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_iam_role_policy" "ecs_task_execute_command" {
  name = "${local.name_prefix}-task-exec-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "datadog_task" {
  count = var.enable_datadog_agent ? 1 : 0

  name               = "${local.name_prefix}-datadog-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_iam_role_policy" "datadog_task_execute_command" {
  count = var.enable_datadog_agent ? 1 : 0

  name = "${local.name_prefix}-datadog-task-exec-policy"
  role = aws_iam_role.datadog_task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "datadog_task_default" {
  count = var.enable_datadog_agent ? 1 : 0

  name = "${local.name_prefix}-datadog-task-default-policy"
  role = aws_iam_role.datadog_task[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "datadog_task_execution" {
  count = var.enable_datadog_agent ? 1 : 0

  name               = "${local.name_prefix}-datadog-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "datadog_task_execution_default" {
  count = var.enable_datadog_agent ? 1 : 0

  role       = aws_iam_role.datadog_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "datadog_task_execution_cloudwatch" {
  count = var.enable_datadog_agent ? 1 : 0

  role       = aws_iam_role.datadog_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy" "datadog_task_execution_secret" {
  count = var.enable_datadog_agent && (var.datadog_api_key_secret_arn != null || var.datadog_api_key_value != null) ? 1 : 0

  name = "${local.name_prefix}-datadog-secret-access"
  role = aws_iam_role.datadog_task_execution[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters"
        ]
        Resource = concat(local.datadog_secret_arns, local.datadog_ssm_parameter_arns)
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_dynatrace_secret" {
  count = var.dynatrace_service_enabled && var.dynatrace_api_token_secret_arn != null ? 1 : 0

  name = "${local.name_prefix}-dynatrace-secret-access"
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]
        Resource = local.dynatrace_secret_arns
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_otel_secret" {
  count = var.otel_service_enabled && var.otel_exporter_otlp_headers_secret_arn != null ? 1 : 0

  name = "${local.name_prefix}-otel-secret-access"
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]
        Resource = local.otel_secret_arns
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == null ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${local.name_prefix}-github-oidc"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${local.name_prefix}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = coalesce(
            var.github_oidc_provider_arn,
            try(aws_iam_openid_connect_provider.github[0].arn, null)
          )
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.github_subject
          }
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = concat(
      [
        aws_iam_role.ecs_task_execution.arn,
        aws_iam_role.ecs_task.arn
      ],
      var.enable_datadog_agent ? [
        aws_iam_role.datadog_task_execution[0].arn,
        aws_iam_role.datadog_task[0].arn
      ] : []
    )
  }

  dynamic "statement" {
    for_each = var.codebuild_enabled ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "codebuild:StartBuild",
        "codebuild:BatchGetBuilds"
      ]
      resources = [
        "arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:project/${local.codebuild_project_name}"
      ]
    }
  }

  dynamic "statement" {
    for_each = length(local.github_secret_describe_arns) > 0 ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["secretsmanager:DescribeSecret"]
      resources = local.github_secret_describe_arns
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${local.name_prefix}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${local.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.enable_datadog_agent ? aws_iam_role.datadog_task_execution[0].arn : aws_iam_role.ecs_task_execution.arn
  task_role_arn            = var.enable_datadog_agent ? aws_iam_role.datadog_task[0].arn : aws_iam_role.ecs_task.arn

  container_definitions = local.container_definitions_json

  dynamic "volume" {
    for_each = local.datadog_volumes
    content {
      name = volume.value
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  lifecycle {
    # Permite que o pipeline registre novas task definitions sem gerar drift no Terraform
    ignore_changes = [container_definitions]

    precondition {
      condition     = !(var.enable_datadog_agent && var.datadog_api_key_secret_arn == null && var.datadog_api_key_value == null)
      error_message = "Quando enable_datadog_agent for true, informe datadog_api_key_secret_arn ou forneca datadog_api_key_value para criar o secret automaticamente."
    }
  }
}

resource "aws_ecs_task_definition" "native" {
  count                    = var.native_service_enabled ? 1 : 0
  family                   = "${local.native_service_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.native_task_cpu
  memory                   = var.native_task_memory
  execution_role_arn       = var.enable_datadog_agent ? aws_iam_role.datadog_task_execution[0].arn : aws_iam_role.ecs_task_execution.arn
  task_role_arn            = var.enable_datadog_agent ? aws_iam_role.datadog_task[0].arn : aws_iam_role.ecs_task.arn

  container_definitions = local.native_container_definitions_json

  dynamic "volume" {
    for_each = local.datadog_volumes
    content {
      name = volume.value
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  lifecycle {
    ignore_changes = [container_definitions]

    precondition {
      condition     = !(var.enable_datadog_agent && var.datadog_api_key_secret_arn == null && var.datadog_api_key_value == null)
      error_message = "Quando enable_datadog_agent for true, informe datadog_api_key_secret_arn ou forneca datadog_api_key_value para criar o secret automaticamente."
    }
  }
}

resource "aws_ecs_task_definition" "dynatrace" {
  count                    = var.dynatrace_service_enabled ? 1 : 0
  family                   = "${local.dynatrace_service_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.dynatrace_task_cpu
  memory                   = var.dynatrace_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = local.dynatrace_container_definitions_json

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  lifecycle {
    ignore_changes = [container_definitions]

    precondition {
      condition     = !(var.dynatrace_service_enabled && var.dynatrace_api_token_secret_arn == null)
      error_message = "Quando dynatrace_service_enabled for true, informe dynatrace_api_token_secret_arn."
    }
  }
}

resource "aws_ecs_task_definition" "otel" {
  count                    = var.otel_service_enabled ? 1 : 0
  family                   = "${local.otel_service_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.otel_task_cpu
  memory                   = var.otel_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = local.otel_container_definitions_json

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  lifecycle {
    ignore_changes = [container_definitions]

    precondition {
      condition     = !(var.otel_service_enabled && var.otel_container_image == null)
      error_message = "Quando otel_service_enabled for true, informe otel_container_image."
    }
  }
}

resource "aws_ecs_service" "this" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  propagate_tags  = "SERVICE"

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "native" {
  count                  = var.native_service_enabled ? 1 : 0
  name                   = "${local.native_service_name}-service"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.native[0].arn
  desired_count          = var.native_desired_count
  launch_type            = "FARGATE"
  propagate_tags         = "SERVICE"
  enable_execute_command = true

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.native[0].arn
    container_name   = "app-native"
    container_port   = var.native_container_port
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "dynatrace" {
  count                  = var.dynatrace_service_enabled ? 1 : 0
  name                   = "${local.dynatrace_service_name}-service"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.dynatrace[0].arn
  desired_count          = var.dynatrace_desired_count
  launch_type            = "FARGATE"
  propagate_tags         = "SERVICE"
  enable_execute_command = true

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dynatrace[0].arn
    container_name   = "app-dynatrace"
    container_port   = var.dynatrace_container_port
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "otel" {
  count                  = var.otel_service_enabled ? 1 : 0
  name                   = "${local.otel_service_name}-service"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.otel[0].arn
  desired_count          = var.otel_desired_count
  launch_type            = "FARGATE"
  propagate_tags         = "SERVICE"
  enable_execute_command = true

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.otel[0].arn
    container_name   = "app-otel"
    container_port   = var.otel_container_port
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
