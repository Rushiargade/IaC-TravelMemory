variable "aws_region" {
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "ubuntu_ami" {
  description = "Ubuntu 22.04 LTS AMI ID (update based on region if different)"
  default     = "ami-0c7217cdde317cfec" # us-east-1 Ubuntu Server 22.04 LTS
}

variable "key_name" {
  description = "Name of the existing SSH key pair in AWS"
  type        = string
  default     = "my-aws-key"
}

variable "allowed_ssh_ip" {
  description = "IP address allowed to SSH to the Web Server"
  type        = string
  default     = "0.0.0.0/0" # Change this to your exact public IP for stricter security
}
