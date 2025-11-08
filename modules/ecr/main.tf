resource "aws_ecr_repository" "this" {
    name= var.name
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
      scan_on_push = false
    }
    encryption_configuration {
      encryption_type = "AES256"
    }

    tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 25 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 25
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
