output "rds_endpoint" {
  value = aws_db_instance.postgres.address
  description = "DNS do banco de dados"
}

output "sqs_url" {
  value = aws_sqs_queue.video_queue.id
  description = "URL da fila SQS"
}

output "s3_bucket_name" {
  value = aws_bucket.video_bucket.bucket
  description = "Nome do bucket S3"
}

output "alb_dns_link" {
  value = aws_lb.api_alb.dns_name
  description = "link para acessar API"
}
