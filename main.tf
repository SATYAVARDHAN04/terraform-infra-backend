resource "aws_lb_target_group" "main" {
  name     = "${var.project}-${var.environment}-${var.component}"
  port     = local.port_number
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  health_check {
    healthy_threshold   = 2
    interval            = 5
    matcher             = "200-299"
    path                = local.health_check_path
    port                = local.port_number
    timeout             = 2
    unhealthy_threshold = 3
  }
}

resource "aws_instance" "main" {
  ami                    = local.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [local.sg_id]
  subnet_id              = local.private_subnet_id
  iam_instance_profile   = "EC2FETCHSSMPARAM"
  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.component}"
  })
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

  connection {
    type     = "ssh"      # SSH or WinRM
    user     = "ec2-user" # Remote username
    password = "DevOps321"
    host     = aws_instance.main.private_ip # Remote address
  }

  provisioner "file" {
    source      = "main.sh"                  # Local file/directory to copy
    destination = "/tmp/${var.component}.sh" # Remote path to place file/content
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/${var.component}.sh",
      "sudo sh /tmp/${var.component}.sh ${var.component} ${var.environment}"
    ]
  }
}

# stop the instance
resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on  = [terraform_data.main]
}

# take note of the AMI of instance
resource "aws_ami_from_instance" "main" {
  name               = "${var.project}-${var.environment}-${var.component}"
  source_instance_id = aws_instance.main.id
  depends_on         = [aws_ec2_instance_state.main]
  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-AMI"
  }
}

# terminate the instance 
resource "terraform_data" "main_terminate" {
  triggers_replace = [
    aws_instance.main.id
  ]

  connection {
    type     = "ssh"      # SSH or WinRM
    user     = "ec2-user" # Remote username
    password = "DevOps321"
    host     = aws_instance.main.private_ip # Remote address
  }

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
  depends_on = [aws_ami_from_instance.main]
}

resource "aws_launch_template" "main" {
  name                                 = "${var.project}-${var.environment}-${var.component}"
  image_id                             = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.micro"
  vpc_security_group_ids               = [local.sg_id]
  iam_instance_profile {
    name = "EC2FETCHSSMPARAM"
  }
  update_default_version               = true # each time we update new version will be default
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  }

  # launch template tags
  tags = {
    Name = "${var.project}-${var.environment}-${var.component}"
  }
}

resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-${var.component}"
  max_size                  = 5
  min_size                  = 1
  desired_capacity          = 2
  health_check_grace_period = 120
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.main.arn]
  vpc_zone_identifier       = local.private_subnet_ids
  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  dynamic "tag" {
    for_each = merge(local.ec2_tags, {
      Name = "${var.project}-${var.environment}-${var.component}"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  timeouts {
    delete = "8m"
  }

}

resource "aws_autoscaling_policy" "main" {
  name                   = "${var.project}-${var.environment}-${var.component}"
  autoscaling_group_name = aws_autoscaling_group.main.id
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = local.alb_listerner_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.rule_header_url]
    }
  }
}