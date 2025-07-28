# Terraform Infrastructure for City Planners

This Terraform project sets up infrastructure for:
- Payload CMS running on ECS Fargate  
- MongoDB Atlas (external connection for CMS)  
- Static Nuxt frontend hosted on S3  
- CloudFront distribution for global CDN delivery  
- Custom domain support via Route 53  
- TLS certificates via AWS Certificate Manager (ACM)  
- Secure secrets management using AWS Secrets Manager  
- Auto-provisioned VPC, public subnets, internet gateway, and route tables  
- Application Load Balancer (ALB) for routing traffic to ECS services  

---

## Setup

In this example, we'll use `richard-serra` as the client project name.

---

### 1. Create Required Secrets

If you haven't already, run the following scripts to create the necessary secrets in AWS Secrets Manager:

```bash
./create-global-secrets.sh
./create-client-secrets.sh richard-serra
```

### 2. Deploy Global Infrastructure

Navigate to the global folder and apply the infrastructure:

```bash
cd global
terraform init
terraform plan -var-file="global.tfvars"
```

Then, if everything looks good, run:

```bash
terraform apply -var-file="global.tfvars"
```

This sets up:

* VPC
* Subnets
* Route tables
* Internet gateway
* Shared MongoDB Atlas cluster

### 3. Deploy Client Instance

Now move to the instances folder and deploy the specific client resources:

```bash
cd ../instances
terraform init
terraform plan -var-file=../clients/richard-serra.tfvars
```

Then, if everything looks good, run:

```bash
terraform apply -var-file=../clients/richard-serra.tfvars
```

