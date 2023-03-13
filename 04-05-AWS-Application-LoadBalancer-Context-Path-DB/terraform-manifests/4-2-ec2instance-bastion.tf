# bastion host - ec2 instance with terraform module
# Jumpbox host
module "ec2_public" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count             = var.bastion_instance_count
  name              = "${var.environment}-BastionHost-${count.index}"
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  subnet_id              = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  vpc_security_group_ids = [module.public_bastion_sg.security_group_id]
  user_data              = file("${path.module}/jumpbox-install.sh")

  # tag
  tags = local.common_tags
}