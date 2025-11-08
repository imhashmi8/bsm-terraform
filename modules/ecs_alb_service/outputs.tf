output "cluster_name" { value = aws_ecs_cluster.this.name }
output "service_name" { value = aws_ecs_service.svc.name }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_arn" { value = aws_lb.this.arn }
output "service_sg_id" {
  description = "Security group ID for the ECS service/tasks"
  value       = aws_security_group.svc.id
}

