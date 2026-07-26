data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}



module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-east-1a","us-east-1b","us-east-1c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "blog_autoscaling" {
  source = "terraform-aws-modules/autoscaling/aws"

  name                = "${var.environment.name}-blog"
  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups     = [module.blog_sg.id]
  instance_type       = var.instance_type
  image_id            = data.aws_ami.app_ami.id
  user_data           = filebase64("${path.module}/user_data.sh") # Change "user_data.sh" if your file has a different name like "web.sh"

  traffic_source_attachments = {
    alb = {
      traffic_source_identifier = module.blog_alb.target_groups["blog_tg"].arn
      traffic_source_type       = "elbv2"
    }
  }
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name               = "${var.environment.name}-blog-alb"
  load_balancer_type = "application"
  internal           = false 
  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = [module.blog_sg.id]

  target_groups = {
    blog_tg = {
      name_prefix       = "${var.environment.name}-"
      backend_protocol  = "HTTP"
      backend_port      = 80
      target_type       = "instance"
      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/" # Change this path if your app uses an implicit index suffix
        port                = "80" # Update this string if your app runs on a custom port like "8080"
        protocol            = "HTTP"
        healthy_threshold   = 2    # Minimizes the check sequence count
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 20
        matcher             = "200-499" # Forces acceptance of standard pages, redirects, and missing paths!
      }
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "blog_tg"
      }
    }
  }
}

module "blog_sg" {
  source = "terraform-aws-modules/security-group/aws"

  vpc_id = module.blog_vpc.vpc_id
  name   = "${var.environment.name}-blog"

  # Official verified version 6 map format with explicit port matching boundaries
  ingress_rules = {
    https = {
      from_port   = 443
      to_port     = 443 # <-- Explicitly required target boundary
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
    http = {
      from_port   = 80
      to_port     = 80  # <-- Explicitly required target boundary
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1" # Allows all protocols outbound
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}
