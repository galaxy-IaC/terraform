# private host - ec2 instance with terraform module
# will be created in private subnet of VPC
module "ec2_private" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count = var.private_instance_count

  name              = "${var.environment}-vm-${count.index}"
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  # monitoring = true
  vpc_security_group_ids = [module.private_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  user_data              = file("${path.module}/app1-install.sh")

  # tags
  tags = local.common_tags
}