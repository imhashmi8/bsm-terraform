output "alb_dns_name" {
  value = aws_lb.this.dns_name
}
output "alb_zone_id" {
  value = aws_lb.this.zone_id
}
output "service_sg_id" {
  value = aws_security_group.svc.id
}
output "cluster_name" {
  value = aws_ecs_cluster.this.name
}
output "service_name" {
  value = aws_ecs_service.svc.name
}

# ALB ARN (so other modules can look up listeners)
output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.this.arn
}

# TG ARN for the service (so other modules can create listener rules)
output "target_group_arn" {
  description = "Target group ARN for the ECS service"
  value       = aws_lb_target_group.tg.arn
}

# Optional: TG name
output "target_group_name" {
  description = "Target group name for the ECS service"
  value       = aws_lb_target_group.tg.name
}
