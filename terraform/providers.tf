provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "self-healing-ec2-fleet"
      ManagedBy = "terraform"
    }
  }
}
