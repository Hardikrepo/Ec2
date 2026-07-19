output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "Prototype HTTP endpoint; add ACM/HTTPS before production use."
  value       = "http://${aws_lb.main.dns_name}"
}

output "custom_domain_url" {
  description = "Route 53 alias URL, if domain_name/hosted_zone_id were set."
  value       = length(aws_route53_record.app) > 0 ? "http://${var.domain_name}" : null
}

output "autoscaling_group_name" {
  description = "Name of the fleet's Auto Scaling Group."
  value       = aws_autoscaling_group.main.name
}

output "notification_topic_arn" {
  description = "SNS topic ARN for on-call notifications."
  value       = aws_sns_topic.notifications.arn
}

output "archive_bucket_name" {
  description = "S3 bucket where terminating instances archive logs."
  value       = aws_s3_bucket.archive.bucket
}

output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}
