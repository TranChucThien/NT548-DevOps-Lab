# Dynamic values for the Terraform configuration
variable "vpc_name" {
  description = "VPC Name"
  default     = "21521464-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet address block"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private Subnet address block"
  default     = "10.0.2.0/24"
}

variable "public_ip" {
  description = "Public IP address for SSH access"
  default = "14.186.95.103/32"
}