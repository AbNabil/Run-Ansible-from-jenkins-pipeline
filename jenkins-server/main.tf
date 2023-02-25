provider "aws" {
    region = "us-west-2"
}
variable availability_zone {}
variable instance_type {}
variable image_name {}
variable ssh_key {}

# VPC
resource "aws_vpc" "main"{
    cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main-public-subnet" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.10.0/24"
    availability_zone = var.availability_zone
}


resource "aws_security_group" "main-sg" {
    name        = "ssh&8080"
    description = "Allow ssh&8080 inbound traffic"
    vpc_id      = aws_vpc.main.id

    ingress {
        description      = "ssh from VPC"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    ingress {
        description      = "open port 8080 from VPC"
        from_port        = 8080
        to_port          = 8080
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name = "allow_ssh&8080"
    }
    }

resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-gw"
  }
}

resource "aws_route_table" "main-route-table" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main-igw.id
    }
    tags = {
        Name: "main-rtb"
    }
}

resource "aws_route_table_association" "a-rt-subnet" {
    subnet_id = aws_subnet.main-public-subnet.id
    route_table_id = aws_route_table.main-route-table.id
}



#EC2
resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file(var.ssh_key)
}

data "aws_ami" "latest-amazon-linux-image"{
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = [var.image_name]
    }
}

resource "aws_instance" "main-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.main-public-subnet.id
    vpc_security_group_ids = [aws_security_group.main-sg.id]
    availability_zone = var.availability_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    
    user_data = file("entry_script.sh")

    tags = {
        Name = "jenkins-server"
    }
}