variable "db_username" {
  description = "Usuário do banco de dados"
  type        = string
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true # Isso impede que a senha apareça nos logs do Terraform
}

variable "aws_region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}