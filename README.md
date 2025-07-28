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

### 4. Post Apply: DNS Setup (if not using Route 53)
If `domain_registered_in_aws = false`, Terraform will not create Route 53 records for you. Instead, you need to manually configure DNS at your registrar to point to your CloudFront distribution. Here’s how:

1. Get Your CloudFront Domain

After you apply your Terraform in the `instances/` folder, run:

```bash
terraform output cloudfront_domain_name
```

You’ll get a value like:

```
d123abcd1234.cloudfront.net
```

2. Login to Your Domain Registrar

Go to the DNS management page for your domain (e.g., Namecheap, GoDaddy, Google Domains).

3. Create the Following Records

| Subdomain            | Type  | Value (Points To)             |
| -------------------- | ----- | ----------------------------- |
| `@` or `example.com` | CNAME | `d123abcd1234.cloudfront.net` |
| `cms`                | CNAME | `d123abcd1234.cloudfront.net` |

* Use @ if your registrar allows it to mean "root domain"
* Make sure both records point to the same CloudFront domain
* TTL can usually stay at the default (e.g. 300 seconds)

4. Allow Time for Propagation

DNS changes may take a few minutes to an hour to propagate. You can verify with:

```bash
dig cms.example.com
```

Or use online tools like https://dnschecker.org.

### 5. Confirm Access
Check outputs:

```bash
terraform output
```

You should see:

* cloudfront_domain_name
* cms_url (if applicable)
* s3_website_url

Try accessing:

* https://<your-client-domain> for Nuxt frontend
* https://cms.<your-client-domain> for Payload (if enabled)
