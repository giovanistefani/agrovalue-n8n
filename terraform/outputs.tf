output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL to access N8N"
  value       = var.certificate_arn != "" ? "https://${var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.n8n.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for N8N data"
  value       = aws_s3_bucket.n8n_data.bucket
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

# Cost estimation outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    fargate_spot_estimated = "~$15-30/month (1-2 tasks)"
    rds_t3_micro          = "~$15-20/month"
    alb                   = "~$16/month"
    nat_gateway           = "~$32/month"
    data_transfer         = "~$5-10/month"
    storage               = "~$2-5/month"
    total_estimated       = "~$85-123/month"
  }
}

output "cost_optimization_tips" {
  description = "Cost optimization recommendations"
  value = [
    "Use Spot instances when possible (enabled by default)",
    "Scale down during off-hours using scheduled scaling",
    "Monitor CloudWatch alarms for cost anomalies",
    "Use S3 lifecycle policies for old backups",
    "Consider using Aurora Serverless for database if usage is sporadic"
  ]
}
