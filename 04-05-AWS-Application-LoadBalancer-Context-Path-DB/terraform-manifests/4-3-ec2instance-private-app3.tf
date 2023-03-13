# APP3 mysql client host - ec2 instance with terraform module
module "ec2_private_app3" {
  depends_on = [module.vpc, module.rdsdb]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count = var.private_instance_count

  name              = "${var.environment}-vm-app3-${count.index}"
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  vpc_security_group_ids = [module.private_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  user_data              = templatefile("app3-ums-install.tmpl", { rds_db_endpoint = module.rdsdb.db_instance_address, app3_port = var.app3_port, app3_db_name = var.app3_db_name, app3_db_user = var.app3_db_user, app3_pwd = var.db_password })

  # tags
  tags = local.common_tags
}