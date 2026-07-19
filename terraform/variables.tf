variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones to spread the fleet across. Must have exactly 3 entries."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "availability_zones must contain exactly 3 zones (ARCHITECTURE.md specifies 3 AZs)."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ (ALB, NAT Gateway)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ (EC2/ASG)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the fleet Launch Template."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "ASG minimum instance count."
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "ASG desired instance count."
  type        = number
  default     = 6
}

variable "asg_max_size" {
  description = "ASG maximum instance count."
  type        = number
  default     = 12
}

variable "notification_email" {
  description = "Optional email address to subscribe to the on-call SNS topic. Leave blank to skip the subscription."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Optional DNS name to alias to the ALB, e.g. app.example.com. Leave blank to skip Route 53."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Optional existing Route 53 public hosted zone ID. Required if domain_name is set."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for Lambda function log groups."
  type        = number
  default     = 14
}
