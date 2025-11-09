output "ecr_repository_url" {
  description = "URI completo do repositório ECR"
  value       = aws_ecr_repository.this.repository_url
}

output "native_ecr_repository_url" {
  description = "URI completo do repositório ECR para a imagem nativa"
  value       = var.native_service_enabled ? aws_ecr_repository.native[0].repository_url : null
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS"
  value       = aws_ecs_service.this.name
}

output "native_ecs_service_name" {
  description = "Nome do serviço ECS nativo"
  value       = var.native_service_enabled ? aws_ecs_service.native[0].name : null
}

output "task_definition_family" {
  description = "Família da task definition usada pelo serviço"
  value       = aws_ecs_task_definition.this.family
}

output "native_task_definition_family" {
  description = "Família da task definition usada pelo serviço nativo"
  value       = var.native_service_enabled ? aws_ecs_task_definition.native[0].family : null
}

output "dynatrace_ecr_repository_url" {
  description = "URI completo do repositório ECR para a imagem Dynatrace"
  value       = var.dynatrace_service_enabled ? aws_ecr_repository.dynatrace[0].repository_url : null
}

output "dynatrace_ecs_service_name" {
  description = "Nome do serviço ECS Dynatrace"
  value       = var.dynatrace_service_enabled ? aws_ecs_service.dynatrace[0].name : null
}

output "dynatrace_task_definition_family" {
  description = "Família da task definition usada pelo serviço Dynatrace"
  value       = var.dynatrace_service_enabled ? aws_ecs_task_definition.dynatrace[0].family : null
}

output "otel_ecr_repository_url" {
  description = "URI completo do repositório ECR para a imagem OpenTelemetry"
  value       = var.otel_service_enabled ? aws_ecr_repository.otel[0].repository_url : null
}

output "otel_ecs_service_name" {
  description = "Nome do serviço ECS OpenTelemetry"
  value       = var.otel_service_enabled ? aws_ecs_service.otel[0].name : null
}

output "otel_task_definition_family" {
  description = "Família da task definition usada pelo serviço OpenTelemetry"
  value       = var.otel_service_enabled ? aws_ecs_task_definition.otel[0].family : null
}

output "load_balancer_dns" {
  description = "Endpoint HTTP público do ALB"
  value       = aws_lb.this.dns_name
}

output "github_actions_role_arn" {
  description = "ARN da role IAM usada pelo GitHub Actions para deploy"
  value       = aws_iam_role.github_actions.arn
}

output "datadog_secret_name" {
  description = "Nome do secret do Datadog usado pelo sidecar"
  value       = var.enable_datadog_agent ? try(aws_secretsmanager_secret.datadog[0].name, var.datadog_api_key_secret_arn) : null
}

output "datadog_secret_arn" {
  description = "ARN do secret do Datadog usado pelo sidecar"
  value       = var.enable_datadog_agent ? try(aws_secretsmanager_secret.datadog[0].arn, var.datadog_api_key_secret_arn) : null
  sensitive   = true
}
