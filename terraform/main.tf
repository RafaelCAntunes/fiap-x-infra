provider "aws" {
  region = "us-east-1"
}

#  Fila SQS (Para o Worker processar)
resource "aws_sqs_queue" "video_queue" {
  name = "video-processing-queue"
}

# Bucket S3 (Para vídeos e ZIPs)
resource "aws_bucket" "video_bucket" {
  bucket = "fiap-x-videos-content"
}

#  Banco de Dados RDS (Postgres)
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  db_name              = "fiap_x_video_db"
  username = var.db_username
  password = var.db_password
  skip_final_snapshot  = true
  publicly_accessible  = true 
}

resource "null_resource" "db_setup" {
  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    command = "psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${aws_db_instance.postgres.db_name} -f ../scripts/seed.sql"
    environment = {
      PGPASSWORD = var.db_password
    }
  }
}

# Define a capacidade mínima e máxima de Workers
resource "aws_appautoscaling_target" "worker_target" {
  max_capacity       = 10 # Máximo de 10 instâncias em picos
  min_capacity       = 1  # Mantém pelo menos 1 instância rodando
  resource_id        = "service/fiap-cluster/${aws_ecs_service.worker_service.name}"
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
    target_value       = 10.0 
    disable_scale_in   = false 
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

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