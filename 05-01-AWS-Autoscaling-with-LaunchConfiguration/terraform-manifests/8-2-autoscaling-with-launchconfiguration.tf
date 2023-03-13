module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "4.1.0"

  # Autoscaling group
  name            = "${local.name}-myasg1"
  use_name_prefix = false

  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  # Changed for testing Instance Refresh
  #desired_capacity = 3

  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  vpc_zone_identifier     = module.vpc.private_subnets
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn

  # associate ALB with ASG
  target_group_arns = module.alb.target_group_arns

  # ASG Lifecycle Hooks
  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  # ASG Instance Refresh
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag", "desired_capacity", "max_size"]
  }

  # ASG Launch configuration
  lc_name   = "${local.name}-myLaunchConfiguration1"
  use_lc    = true
  create_lc = true

  image_id      = data.aws_ami.amzlinux2.id
  instance_type = var.instance_type
  key_name      = var.instance_keypair
  user_data     = file("${path.module}/app1-install.sh")

  ebs_optimized     = true
  enable_monitoring = true

  security_groups             = [module.private_sg.security_group_id]
  associate_public_ip_address = false

  # spot instance - optional
  spot_price = "0.014"

  # Change for Instance Refresh test
  #spot_price = "0.016"

  # associate another disk
  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp2"
      volume_size           = "20"
    },
  ]

  # root disk property
  root_block_device = [
    {
      delete_on_termination = true
      encrypted             = true
      volume_size           = "15"
      volume_type           = "gp2"
    },
  ]

  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "optional" # At production grade you can change to "required"
  }

  tags = local.asg_tags
}