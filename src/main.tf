resource "aws_vpc" "poc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-vpc"
  }
}
# Subnets Publicas
resource "aws_subnet" "subnet_publica" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.poc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-subnet-${count.index + 1}"
  }
}
# Subnets Privadas
resource "aws_subnet" "subnet_privada" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.poc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.env}-private-subnet-${count.index + 1}"
  }
}
# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.poc.id
  tags = {
    Name = "${var.env}-igw"
  }
}
# Elastic IP do NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.env}-nat-eip"
  }
}
# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet_publica[0].id
  tags = {
    Name = "${var.env}-nat-gw"
  }
}
# Route Table Publica
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.poc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.env}-public-rt"
  }
}
# Associação das Subnets publicas ao Route Table publica
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.subnet_publica[count.index].id
  route_table_id = aws_route_table.public.id
}
# Route Table Privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.poc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.env}-private-rt"
  }
}
# Associação das Subnets privadas ao Route Table privada
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.subnet_privada[count.index].id
  route_table_id = aws_route_table.private.id
}
##############################################################

# Criação dos recursos para suportar as aplicações

resource "aws_security_group" "sg_aplicacoes" {
  name        = "sg_aplicacoes"
  description = "HTTP, HTTPS e Redis"
  vpc_id      = aws_vpc.poc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Saida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-aplicacoes"
  }
}

# criacao da funcao IAM
resource "aws_iam_role" "ssm_role" {
  name = "ssm-to-aplicacoes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
# Colocando a política do AWS Systems Manager na funcao
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Criar um perfil da EC2
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-app-ec2-python"
  role = aws_iam_role.ssm_role.name
}

#Criando IP fixo para as EC2
resource "aws_eip" "app_python_ip_fixo" {
  domain = "vpc"
  tags = {
    Name = "app-python-ip_fixo"
  }
}

#Servidores
resource "aws_instance" "app_python" {
  ami = "ami-04b4f1a9cf54c11d0"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.subnet_publica[0].id
  security_groups = [aws_security_group.sg_aplicacoes.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3 python3-pip
              apt install python3-flask python3-flask-caching python3-redis -y

              mkdir -p /app/python-app/app-10-seg
              mkdir -p /app/python-app/app-10-seg/templates


              echo "${filebase64("${path.module}/../app-10-seg/main.py")}" | base64 --decode > /app/python-app/app-10-seg/main.py
              echo "${filebase64("${path.module}/../app-10-seg//routes.py")}" | base64 --decode > /app/python-app/app-10-seg/routes.py
              echo "${filebase64("${path.module}/../app-10-seg//templates/datetime.html")}" | base64 --decode > /app/python-app/app-10-seg/templates/datetime.html
              echo "${filebase64("${path.module}/../app-10-seg//templates/index.html")}" | base64 --decode > /app/python-app/app-10-seg/templates/index.html

              cd /app/python-app/app-10-seg/
              nohup python3 main.py > app-10-seg.log 2>&1 &

              EOF
  tags = {
    Name = "PythonApp"
  }
}

#Attachando IP fixo a EC2 python
resource "aws_eip_association" "app_python_eip_assoc" {
  instance_id   = aws_instance.app_python.id
  allocation_id = aws_eip.app_python_ip_fixo.id
}

############################# Elastic Beanstalk e API   ###################################

# Elastic Beanstalk
resource "aws_elastic_beanstalk_application" "node_app" {
  name        = "node-app"
  description = "Node.js Application"
}

# Versao da aplicação
resource "aws_elastic_beanstalk_application_version" "app_version" {
  name        = "node-app-v1"
  application = aws_elastic_beanstalk_application.node_app.name
  description = "Versao inicial da aplicação node"
  bucket      = aws_s3_bucket.app_bucket.id
  key         = aws_s3_object.node_app_zip.key
}

# S3 Bucket para armazenar o arquivo .zip da aplicação
resource "aws_s3_bucket" "app_bucket" {
  bucket = "node-app-bucket-${var.env}"
  tags = {
    Name = "node-app-bucket"
  }
}

# S3 Object para o arquivo .zip da aplicação
resource "aws_s3_object" "node_app_zip" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "node-app.zip"
  source = "${path.module}/../node-app.zip"  
  etag   = filemd5("${path.module}/../node-app.zip")
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "env" {
  name                = "node-app-env"
  application         = aws_elastic_beanstalk_application.node_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.4.3 running Node.js 20"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.poc.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", aws_subnet.subnet_publica[*].id)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ssm_instance_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = "production"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "/health"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "HealthCheckSuccessThreshold"
    value     = "Ok"
  }


  version_label = aws_elastic_beanstalk_application_version.app_version.name
}

# # API Gateway
# resource "aws_api_gateway_rest_api" "api" {
#   name        = "node-app-api"
#   description = "API Gateway for Node.js Application"
# }

# resource "aws_api_gateway_resource" "resource" {
#   rest_api_id = aws_api_gateway_rest_api.api.id
#   parent_id   = aws_api_gateway_rest_api.api.root_resource_id
#   path_part   = "{proxy+}"
# }

# resource "aws_api_gateway_method" "method" {
#   rest_api_id   = aws_api_gateway_rest_api.api.id
#   resource_id   = aws_api_gateway_resource.resource.id
#   http_method   = "ANY"
#   authorization = "NONE"

#   request_parameters = {
#     "method.request.path.proxy" = true
#   }
# }

# resource "aws_api_gateway_integration" "integration" {
#   rest_api_id             = aws_api_gateway_rest_api.api.id
#   resource_id             = aws_api_gateway_resource.resource.id
#   http_method             = aws_api_gateway_method.method.http_method
#   integration_http_method = "POST"
#   type                    = "HTTP_PROXY"
#   uri                     = "http://${aws_elastic_beanstalk_environment.env.endpoint_url}/{proxy}"
#   cache_key_parameters    = ["method.request.path.{proxy}"]
#   cache_namespace = "integration"
# }

# resource "aws_api_gateway_deployment" "deployment" {
#   rest_api_id = aws_api_gateway_rest_api.api.id
#   stage_name  = "prod"
#     depends_on = [
#     aws_api_gateway_method.method,
#     aws_api_gateway_integration.integration
#   ]
# }

# resource "aws_api_gateway_stage" "stage" {
#   stage_name    = "prod"
#   rest_api_id   = aws_api_gateway_rest_api.api.id
#   deployment_id = aws_api_gateway_deployment.deployment.id

#   cache_cluster_enabled = true
#   cache_cluster_size    = "0.5"
# }

############################## MONITORAMENTO #######################################
# Log Group - aplicação Python
resource "aws_cloudwatch_log_group" "python_app_logs" {
  name = "/aws/ec2/python-app"
  retention_in_days = 30
}

# Log Group - aplicação Node
resource "aws_cloudwatch_log_group" "node_app_logs" {
  name = "/aws/elasticbeanstalk/node-app"
  retention_in_days = 30
}

# Agente CloudWatch p/ EC2 pythom
resource "aws_cloudwatch_log_stream" "python_app_log_stream" {
  name           = "python-app-log-stream"
  log_group_name = aws_cloudwatch_log_group.python_app_logs.name
}

# Agente CloudWatch p/ EC2 node
resource "aws_cloudwatch_log_stream" "node_app_log_stream" {
  name           = "node-app-log-stream"
  log_group_name = aws_cloudwatch_log_group.node_app_logs.name
}

# Alarmes
resource "aws_cloudwatch_metric_alarm" "python_app_cpu_alarm" {
  alarm_name          = "python-app-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta de alta utilização de CPU na instância Python App"
  dimensions = {
    InstanceId = aws_instance.app_python.id
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "python_app_memory_alarm" {
  alarm_name          = "python-app-memory-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = 300  
  statistic           = "Average"
  threshold           = 80 
  alarm_description   = "Alerta de alta utilização de memória na instância Python App"
  dimensions = {
    InstanceId = aws_instance.app_python.id
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "node_app_cpu_alarm" {
  alarm_name          = "node-app-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElasticBeanstalk"
  period              = 300  
  statistic           = "Average"
  threshold           = 80   
  alarm_description   = "Alerta de alta utilização de CPU no ambiente Node.js App"
  dimensions = {
    EnvironmentName = aws_elastic_beanstalk_environment.env.name
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
}

# Topico SNS p/ receber os alarmes
resource "aws_sns_topic" "alarm_notifications" {
  name = "alarm-notifications-topic"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = "seiji.igari@hotmail.com"
}

##############################  DASHBOARD  ####################################

# Dashboard no CloudWatch
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "app-monitoring-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app_python.id],
            ["AWS/ElasticBeanstalk", "CPUUtilization", "EnvironmentName", aws_elastic_beanstalk_environment.env.name]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Uso de CPU"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = "us-east-1"
          query = "SOURCE '/aws/ec2/python-app' | SOURCE '/aws/elasticbeanstalk/node-app'"
          title = "Logs das Aplicações"
        }
      }
    ]
  })
}