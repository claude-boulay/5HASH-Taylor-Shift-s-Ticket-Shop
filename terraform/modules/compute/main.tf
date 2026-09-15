resource "aws_key_pair" "this" {
  key_name   = "${var.project}-${var.environment}"
  public_key = file(var.public_key_path)
  tags       = var.tags

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_instance" "app" {
  for_each = { for i in range(var.instance_count) : "app${i + 1}" => i }

  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = element(var.public_subnet_ids, each.value % length(var.public_subnet_ids))
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.this.key_name

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-${each.key}"
    Role = "webservers"
  })
}

resource "aws_lb" "this" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
