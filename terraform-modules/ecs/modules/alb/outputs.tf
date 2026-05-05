output "alb_dns_name" {
  description = "Public DNS name of the ALB  the app's entry point"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN of the target group  passed to ECS service"
  value       = aws_lb_target_group.this.arn
}

output "listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}
