output "ecr_repository_url" {
  description = "URI completo do repositório ECR"
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS"
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "Família da task definition usada pelo serviço"
  value       = aws_ecs_task_definition.this.family
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
