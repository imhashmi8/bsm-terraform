locals {
  log_group = "/ecs/${var.name}"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = local.log_group
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  tags = var.tags
}

# IAM
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# SGs
resource "aws_security_group" "alb" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_security_group" "svc" {
  name   = "${var.name}-svc-sg"
  vpc_id = var.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# ALB
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  tags               = var.tags
}

resource "aws_lb_target_group" "tg" {
  name        = "${var.name}-tg"
  vpc_id      = var.vpc_id
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  health_check {
    path    = "/"
    matcher = "200-399"
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Task & Service
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name}-taskdef"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name         = "app"
    image        = var.image
    portMappings = [{ containerPort = var.container_port, hostPort = var.container_port }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "svc" {
  name            = "${var.name}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.svc.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}
