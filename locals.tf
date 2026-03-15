locals {
  ami                = data.aws_ami.joindevops.id
  sg_id              = data.aws_ssm_parameter.sg_id.value
  private_subnet_id  = split(",", data.aws_ssm_parameter.private_subnet_id.value)[0]
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_id.value)
  ec2_tags = merge(var.common_tags, {
    environment = var.environment
  })
  alb_listerner_arn = "${var.component}" == "frontend" ? data.aws_ssm_parameter.frontend_alb_listerner_arn.value : data.aws_ssm_parameter.backend_alb_listerner_arn.value
  port_number       = "${var.component}" == "frontend" ? 80 : 8080
  health_check_path = "${var.component}" == "frontend" ? "/" : "/health"
  rule_header_url   = "${var.component}" == "frontend" ? "${var.environment}.${var.zone_name}" : "${var.component}.backend-${var.environment}.${var.zone_name}"
}