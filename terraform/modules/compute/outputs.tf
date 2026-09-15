output "instance_ids" { value = { for k, i in aws_instance.app : k => i.id } }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
