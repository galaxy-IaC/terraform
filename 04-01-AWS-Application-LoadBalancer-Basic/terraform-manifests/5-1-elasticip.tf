# create elastic IP for bastion host
resource "aws_eip" "bastion_eip" {
  depends_on = [module.ec2_public, module.vpc]
  count      = var.bastion_instance_count
  instance   = module.ec2_public[count.index].id
  vpc        = true

  tags = local.common_tags

  # local-exec provisioner which destroy-time provisioner, be triggered during deletion of resource
  provisioner "local-exec" {
    command     = "echo destroy time `date` >> destroy-time-prov.txt"
    working_dir = "local-exec-output-files/"
    when        = destroy
    #on_failure = continue
  }
}

output "elastic_IP_of_instance" {
  value = aws_eip.bastion_eip.*.public_ip
}

