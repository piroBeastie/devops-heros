# A terraform demo that uses only local providers, so the full
# init -> plan -> apply -> state -> destroy cycle can be run without
# any cloud account or credentials.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "student_name" {
  description = "Name written into the generated file"
  type        = string
  default     = "Nanakjot Singh Chahal"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

resource "random_pet" "server" {
  length    = 2
  separator = "-"
}

resource "local_file" "notes" {
  filename = "${path.module}/generated/server-notes.txt"

  content = <<-EOT
    Managed by Terraform
    --------------------
    server name : ${random_pet.server.id}
    environment : ${var.environment}
    student     : ${var.student_name}
  EOT
}

output "server_name" {
  description = "Randomly generated server name"
  value       = random_pet.server.id
}

output "notes_file" {
  description = "Path of the file terraform created"
  value       = local_file.notes.filename
}
