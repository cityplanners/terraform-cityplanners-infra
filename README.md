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

You should only need to run the `create-global-secrets.sh` file once to set up.

---

### 1. Create Required Secrets

If you haven't already, run the following scripts to create the necessary secrets in AWS Secrets Manager and generate the client tfvars file:

```bash
./create-client.sh richard-serra
```

### 2. Deploy Infrastructure

Apply Terraform from the project root using the generated client variables:

```bash
terraform init
terraform plan -var-file="clients/richard-serra.tfvars"
```

Then, if everything looks good, run:

```bash
terraform apply -var-file="clients/richard-serra.tfvars"
```

This sets up:

* VPC
* Subnets
* Route tables
* Internet gateway
* Shared MongoDB Atlas cluster
* CloudFront, TLS, and DNS routing

### 3. Post Apply: DNS Setup (if not using Route 53)

If `domain_registered_in_aws = false`, Terraform will not create Route 53 records for you. Instead, you need to manually configure DNS at your registrar. This involves two steps: SSL certificate validation and pointing your domain to CloudFront.

#### Step 1: SSL Certificate Validation (Required First)

Before your infrastructure can work with HTTPS, you need to validate your SSL certificate by adding a DNS validation record:

1. **Get the Certificate Validation Record**
   
   After running `terraform apply`, if you get SSL certificate errors, get the validation details:
   ```bash
   terraform state show 'module.client_instance.aws_acm_certificate.cert'
   ```
   
   Look for the `domain_validation_options` section which will show something like:
   ```
   resource_record_name  = "_81a9ea9c5fce96ad3f4c56eeae3bfd3b.yourdomain.com."
   resource_record_type  = "CNAME"
   resource_record_value = "_77ea313e370c0389aa39b11f733529ba.xlfgrmvvlj.acm-validations.aws."
   ```

2. **Add the Validation CNAME Record**
   
   Login to your domain registrar and add this exact CNAME record:
   
   | Record Type | Name/Host | Value/Points To |
   | ----------- | --------- | --------------- |
   | **CNAME** | `_81a9ea9c5fce96ad3f4c56eeae3bfd3b` | `_77ea313e370c0389aa39b11f733529ba.xlfgrmvvlj.acm-validations.aws.` |
   
   **Important Notes:**
   - Use the exact values from your certificate output
   - Some registrars automatically append your domain name, so you may only need the hash part
   - Include the trailing dot (`.`) in the value if your registrar requires it
   - TTL can be set to default (300-3600 seconds)

3. **Wait for Certificate Validation**
   
   Monitor the certificate status (takes 5-30 minutes):
   ```bash
   aws acm describe-certificate --certificate-arn YOUR_CERT_ARN --region us-east-1 --query 'Certificate.Status'
   ```
   
   When it returns `"ISSUED"`, proceed to run `terraform apply` again.

#### Step 2: Point Your Domain to CloudFront (After SSL is Working)

Once your SSL certificate is validated and `terraform apply` completes successfully:

1. **Get Your CloudFront Domain**
   
   ```bash
   terraform output cloudfront_domain_name
   ```
   
   You'll get a value like:
   ```
   d123abcd1234.cloudfront.net
   ```

2. **Create Domain Records**
   
   Go to your domain registrar's DNS management page and create these records:
   
   | Subdomain | Type | Value (Points To) |
   | --------- | ---- | ----------------- |
   | `@` or root domain | CNAME or A | `d123abcd1234.cloudfront.net` |
   | `cms` | CNAME | `d123abcd1234.cloudfront.net` |
   
   **Notes:**
   - Use `@` if your registrar supports it for the root domain
   - Some registrars require an A record for the root domain instead of CNAME
   - Both records should point to the same CloudFront domain
   - TTL can stay at default (300-3600 seconds)

3. **Allow Time for Propagation**
   
   DNS changes may take a few minutes to an hour to propagate. You can verify with:
   ```bash
   dig yourdomain.com
   dig cms.yourdomain.com
   ```
   
   Or use online tools like https://dnschecker.org.

#### Troubleshooting

- **SSL Certificate Errors**: Make sure you completed Step 1 and the certificate shows as `ISSUED`
- **Domain Not Resolving**: Double-check that your CNAME records point to the correct CloudFront domain
- **Mixed Content Warnings**: Ensure your application is configured to use HTTPS for all resources

### 4. Confirm Access
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

## Notes

* This project uses a unified root module to manage global and per-client resources.
* MongoDB Atlas is provisioned once globally and accessed by all clients.
* Secrets are stored in AWS Secrets Manager and dynamically injected into ECS services.
