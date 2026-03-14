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
  publicly_accessible  = true # Para fins de teste/estudo
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