output "repository_url" {
  value       = aws_ecr_repository.this.repository_url   # no quotes!
  description = "The full ECR repository URI"
}

output "repository_name" {
    value = aws_ecr_repository.this.name
}