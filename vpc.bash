#!/bin/bash
# Replace these variables with your desired values
VPC_NAME="sadiya-vpc"
VPC_CIDR_BLOCK="192.168.0.0/16"
PUBLIC_SUBNET_NAME="PublicSubnet"
PUBLIC_SUBNET_CIDR_BLOCK="192.168.0.0/24"
PRIVATE_SUBNET_NAME="PrivateSubnet"
PRIVATE_SUBNET_CIDR_BLOCK="192.168.1.0/24"
REGION="us-east-2"  # Replace with your desired region
KEY_NAME="cloud"
# Create VPC
echo "Creating VPC..."
vpc_id=$(aws ec2 create-vpc --cidr-block $VPC_CIDR_BLOCK --query 'Vpc.VpcId' --output text --region $REGION)
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value=$VPC_NAME --region $REGION
# Create public subnet
echo "Creating Public Subnet..."
public_subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $PUBLIC_SUBNET_CIDR_BLOCK --query 'Subnet.SubnetId' --output text --region $REGION)
aws ec2 create-tags --resources $public_subnet_id --tags Key=Name,Value=$PUBLIC_SUBNET_NAME --region $REGION
# Create private subnet
echo "Creating Private Subnet..."
private_subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $PRIVATE_SUBNET_CIDR_BLOCK --query 'Subnet.SubnetId' --output text --region $REGION)
aws ec2 create-tags --resources $private_subnet_id --tags Key=Name,Value=$PRIVATE_SUBNET_NAME --region $REGION
# Create an Internet Gateway (IGW)
echo "Creating Internet Gateway..."
igw_id=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region $REGION)
aws ec2 create-tags --resources $igw_id --tags Key=Name,Value="${VPC_NAME}_IGW" --region $REGION
# Attach the Internet Gateway to the VPC
echo "Attaching Internet Gateway to VPC..."
aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id --region $REGION
# Create a public route table
echo "Creating Public Route Table..."
public_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --query 'RouteTable.RouteTableId' --output text --region $REGION)
aws ec2 create-tags --resources $public_route_table_id --tags Key=Name,Value="${VPC_NAME}_Public_RT" --region $REGION
# Create a private route table
echo "Creating Private Route Table..."
private_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --query 'RouteTable.RouteTableId' --output text --region $REGION)
aws ec2 create-tags --resources $private_route_table_id --tags Key=Name,Value="${VPC_NAME}_Private_RT" --region $REGION
# Add a route to the public route table to route all traffic to the Internet Gateway
echo "Configuring Public Route Table..."
aws ec2 create-route --route-table-id $public_route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id --region $REGION
# Create a security group with inbound rules for ports 22 and 80
echo "Creating Security Group..."
security_group_id=$(aws ec2 create-security-group --group-name MySecurityGroup --description "My security group" --vpc-id $vpc_id --query 'GroupId' --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
# User data to install httpd on the instance
USER_DATA_BASE64=$(echo -n "#!/bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl status httpd" | base64 -w0)
# Launch the EC2 instance with auto-assign public IP enabled
echo "Launching EC2 instance..."
instance_id=$(aws ec2 run-instances \
  --image-id ami-098dd3a86ea110896 \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --security-group-ids $security_group_id \
  --subnet-id $public_subnet_id \
  --user-data "$USER_DATA_BASE64" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=\"$INSTANCE_NAME\"}]" \
  --associate-public-ip-address \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region $REGION)
# Explicitly associate the subnets with their respective route tables
echo "Associating Subnets with Route Tables..."
aws ec2 associate-route-table --subnet-id $public_subnet_id --route-table-id $public_route_table_id --region $REGION
# Get the public IP address of the instance
public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region $REGION)
echo "EC2 instance launched successfully."
echo "Instance ID: $instance_id"
echo "Public IP: $public_ip"
