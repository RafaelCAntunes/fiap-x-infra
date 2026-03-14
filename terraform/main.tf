terraform {
  backend "s3" {
    bucket = "tf-state-fiap-x-bucket" 
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "fiap_sg" {
  name        = "fiap-video-sg"
  description = "Acesso para API, Worker e RDS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "video_bucket" {
  bucket = "fiap-x-videos-content"
}

resource "aws_sqs_queue" "video_queue" {
  name                       = "video-processing-queue"
  visibility_timeout_seconds = 600 # 10 min
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  db_name                = "fiap_x_video_db"
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.fiap_sg.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "null_resource" "db_setup" {
  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    # Garante que as tabelas users e videos existam antes dos apps subirem
    command = "psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${aws_db_instance.postgres.db_name} -f ../scripts/seed.sql"
    environment = {
      PGPASSWORD = var.db_password
    }
  }
}

resource "aws_lb" "api_alb" {
  name               = "fiap-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fiap_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "api_tg" {
  name        = "api-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

resource "aws_ecs_cluster" "fiap_cluster" {
  name = "fiap-cluster"
}

resource "aws_ecs_task_definition" "worker_task" {
  family                   = "worker-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = jsonencode([{
    name  = "worker"
    image = "hello-world" # so um placeholder 
  }])
}

resource "aws_ecs_service" "worker_service" {
  name            = "worker-service"
  cluster         = aws_ecs_cluster.fiap_cluster.id
  task_definition = aws_ecs_task_definition.worker_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.fiap_sg.id]
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}


resource "aws_appautoscaling_target" "worker_target" {
    depends_on = [aws_ecs_service.worker_service]
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/fiap-cluster/worker-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_sqs_policy" {
  name               = "sqs-backlog-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker_target.resource_id
  scalable_dimension = aws_appautoscaling_target.worker_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 10.0 # Tenta manter 10 mensagens por Worker
    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"
      unit        = "Count"
      dimensions {
        name  = "QueueName"
        value = aws_sqs_queue.video_queue.name
      }
    }
  }
}
