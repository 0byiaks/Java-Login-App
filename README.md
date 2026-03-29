# Java Login App — Deployment Guide

## Pre-Deployment

### Create Global AMI

- AWS CLI
- CloudWatch agent
- Install AWS SSM agent

### Create Golden AMI using Global AMI for Nginx application

- Install Nginx
- Push custom memory metrics to CloudWatch

### Create Golden AMI using Global AMI for Apache Tomcat application

- Install Apache Tomcat
- Configure Tomcat as systemd service
- Install JDK 11
- Push custom memory metrics to CloudWatch

### Create Golden AMI using Global AMI for Apache Maven Build Tool

- Install Apache Maven
- Install Git
- Install JDK 11
- Update Maven Home to the system PATH environment variable

---

## VPC Deployment

Deploy AWS infrastructure resources as shown in the architecture diagram.

### VPC (Network Setup)

- Build VPC network (`192.168.0.0/16`) for Bastion Host deployment as per the architecture shown above.
- Build VPC network (`172.32.0.0/16`) for deploying highly available and auto-scalable application servers as per the architecture shown above.
- Create NAT Gateway in public subnet and update private subnet associated route table accordingly to route the default traffic to NAT for outbound internet connection.
- Create Transit Gateway and associate both VPCs to the Transit Gateway for private communication.
- Create Internet Gateway for each VPC and update public subnet associated route table accordingly to route the default traffic to IGW for inbound/outbound internet connection.

### Bastion

- Deploy Bastion Host in the public subnet with EIP associated.
- Create security group allowing port 22 from the public internet.

### Maven (Build)

- Create EC2 instance using Maven Golden AMI.
- Clone GitHub repository to VS Code and update `pom.xml` with Sonar and JFrog deployment details.
- Add `settings.xml` file to the root folder of the repository with the JFrog credentials and JFrog repo to resolve the dependencies.
- Update `application.properties` file with JDBC connection string to authenticate with MySQL.
- Push the code changes to a feature branch of the GitHub repository.
- Raise a pull request to approve the PR and merge the changes to the master branch.
- Log in to the EC2 instance and clone the GitHub repository.
- Build the source code using Maven arguments `-s settings.xml`.
- Integrate Maven build with Sonar Cloud and generate analysis dashboard with default Quality Gate profile.

---

## 3-Tier Architecture

### Database (RDS)

- Deploy Multi-AZ MySQL RDS instance into private subnets.
- Create security group allowing port 3306 from app instances and from Bastion Host.

### Tomcat (Backend)

- Create private-facing Network Load Balancer and target group.
- Create launch configuration with the below configuration:
  - Tomcat Golden AMI
  - User Data to deploy `.war` artifact from JFrog into the `webapps` folder.
  - Security group allowing port 22 from Bastion Host and port 8080 from private NLB.
- Create Auto Scaling Group.

### Nginx (Frontend)

- Create public-facing Network Load Balancer and target group.
- Create launch configuration with the below configuration:
  - Nginx Golden AMI
  - User Data to update `proxy_pass` rules in `nginx.conf` and reload the Nginx service.
  - Security group allowing port 22 from Bastion Host and port 80 from public NLB.
- Create Auto Scaling Group.

---

## Application Deployment

- Artifact deployment is taken care of by the User Data script during application tier EC2 instance launch.
- Log in to MySQL database from the application server using MySQL CLI client and create database and table schema to store the user login data (instructions are updated in `README.md` file in the GitHub repo).

---

## Post-Deployment

- Configure cron job to push the Tomcat application log data to an S3 bucket and rotate log data to remove log data on the server after the data is pushed to the S3 bucket.
- Configure CloudWatch alarms to send e-mail notification when database connections exceed a threshold of 100.

---

## Validation

- Verify that you as an administrator are able to log in to EC2 instances from Session Manager and from the Bastion Host.
- Verify that you as an end user are able to access the application from a public internet browser.
