provider "aws" {
  region = var.region
}

locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  subnet_config  = { for idx, az in var.availability_zones : az => var.public_subnet_cidrs[idx] }
  github_subject = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/${var.github_branch}"

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
        "export DD_AGENT_HOST=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4); exec java -javaagent=${var.datadog_java_agent_path} $JAVA_TOOL_OPTIONS -jar app.jar"
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

  container_definitions_list = [for c in [local.app_container_definition, local.datadog_container_definition] : c if c != null]
  container_definitions_json = jsonencode(local.container_definitions_list)

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

  ingress {
    description     = "Trafego do ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
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

  lifecycle {
    prevent_destroy = true
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

resource "aws_iam_role" "datadog_task" {
  count = var.enable_datadog_agent ? 1 : 0

  name               = "${local.name_prefix}-datadog-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
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
          "secretsmanager:GetSecretValue"
        ]
        Resource = local.datadog_secret_arns
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
