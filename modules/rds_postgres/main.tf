# Subnet Group (private subnets)
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

# Security Group for the DB
resource "aws_security_group" "db" {
  name        = "${var.name}-rds-sg"
  description = "Allow PostgreSQL traffic from ECS service"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

# Inbound: allow 5432 only from specified SGs
# Inbound: allow 5432 only from specified SGs
resource "aws_security_group_rule" "allow_from_ecs" {
  count                    = length(var.allowed_sg_ids)
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_sg_ids[count.index]
}


# Outbound: allow all (for monitoring / patching)
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.db.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Parameter Group (optional tuning)
resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg"
  family = "postgres${replace(var.engine_version, "/\\..*$/", "")}" # e.g., postgres15
  tags   = var.tags
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "this" {
  identifier                   = "${var.name}-pg"
  engine                       = "postgres"
  engine_version               = var.engine_version
  instance_class               = var.instance_class

  # Storage settings
  storage_type                 = "gp3"
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  storage_encrypted            = true

  # Networking
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.db.id]
  publicly_accessible          = false
  multi_az                     = var.multi_az

  # Auth - managed by Secrets Manager (no hardcoded password)
  username                     = "dbadmin"
  manage_master_user_password  = true

  # Maintenance & backups
  backup_retention_period      = var.backup_retention
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = false
  copy_tags_to_snapshot        = true
  auto_minor_version_upgrade   = true

  # DB name and params
  db_name                      = var.db_name
  parameter_group_name         = aws_db_parameter_group.this.name

  # Monitoring
  performance_insights_enabled = var.performance_insights

  tags = merge(var.tags, { Name = "${var.name}-rds" })
}
