###Creating VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

tags = {
    Name = "web-vpc"
  }
}

resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"  
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
    Name = "web-sub1a"
  }
}

resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"  
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    tags = {
    Name = "web-sub1b"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "web-gw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  } 
  tags = {
    Name = "web-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "mysg" {
  name        = "mysg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "web-sg"
  }

  }

resource "aws_s3_bucket" "example" {
  bucket = "myasayeelabprojectwebsite2024"
  tags = {
    Name = "web-s3bucket"
  }
}

/*resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}*/

resource "aws_s3_object" "index" {
    bucket = aws_s3_bucket.example.id
    key = "index.html"
    source = "index.html"
   # acl = "public-read"
    content_type = "text/html"

}

resource "aws_iam_role" "webiam_role" {
  name = "webiam_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "webiam_role_attachment" {
  role       = aws_iam_role.webiam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "webiam_role_profile" {
  name = "example_profile"
  role = aws_iam_role.webiam_role.name
}

resource "aws_instance" "webserver1" {
  ami                    = "ami-0005e0cfe09cc9050"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub1.id
  key_name               = "AWS-Key-Pair"
  iam_instance_profile = aws_iam_instance_profile.webiam_role_profile.name
  user_data              = base64encode(file("uscript.sh"))
    
    tags = {
    tag-key = "webserver1"
  }

}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0005e0cfe09cc9050"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub2.id
  key_name               = "AWS-Key-Pair"
  iam_instance_profile = aws_iam_instance_profile.webiam_role_profile.name
  user_data              = base64encode(file("uscript.sh"))

    tags = {
    tag-key = "webserver2"
  }

}

#create alb
resource "aws_lb" "webalb" {
  name               = "webalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.mysg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web-lb"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
  tags = {
    Name = "web-tg"
  }
  
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.webalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.webalb.dns_name
}





