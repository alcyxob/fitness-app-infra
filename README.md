# Fitness App Infrastructure

This repository contains Terraform configurations for deploying the Fitness App infrastructure on AWS using Lambda, API Gateway, ECR, and S3.

## 🏗️ Architecture Overview

### Components:
- **AWS Lambda**: Containerized Go API (arm64, 256MB, 30s timeout)
- **API Gateway HTTP API**: Routes all HTTP requests to Lambda
- **Amazon ECR**: Docker container registry (IMMUTABLE tags)
- **Amazon S3**: Video upload storage with lifecycle management
- **IAM Roles**: Lambda execution role with least-privilege access
- **CloudWatch**: Lambda logging

### Security Features:
- ✅ **Instance Profile Authentication**: App Runner uses IAM roles (no hardcoded credentials)
- ✅ **Least Privilege Access**: Minimal required permissions for S3 and ECR
- ✅ **Private S3 Bucket**: All access via pre-signed URLs
- ✅ **Encrypted Storage**: S3 server-side encryption enabled
- ✅ **Network Security**: Private container networking

## 📁 Project Structure

```
fitness-app-infra/
├── environments/
│   └── dev/
│       ├── main.tf           # Main infrastructure resources
│       ├── iam.tf            # IAM roles and policies
│       ├── variables.tf      # Input variables
│       ├── outputs.tf        # Output values
│       └── terraform.tfvars.example
├── versions.tf               # Terraform and provider versions
└── README.md
```

## 🚀 Quick Start

### Prerequisites:
- [Terraform](https://www.terraform.io/downloads.html) >= 1.3
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate permissions
- Docker image pushed to ECR (or use `latest` tag initially)

### 1. Clone and Configure

```bash
cd fitness-app-infra/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

### 2. Set Required Variables

Edit `terraform.tfvars`:
```hcl
# Required sensitive variables
database_uri = "mongodb+srv://username:password@cluster.mongodb.net/fitness_app_dev"
jwt_secret   = "your-super-secure-jwt-secret-minimum-32-characters-long"

# Optional customizations
aws_region   = "eu-west-1"
environment  = "dev"
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Get Deployment Info

```bash
terraform output deployment_info
```

## 🔧 Configuration Options

### App Runner Scaling
```hcl
min_instances    = 1      # Minimum instances
max_instances    = 5      # Maximum instances  
max_concurrency  = 100    # Requests per instance
```

### Resource Sizing
```hcl
app_runner_cpu    = "1 vCPU"  # 0.25, 0.5, 1, 2, 4 vCPU
app_runner_memory = "2 GB"    # 0.5-12 GB
```

### S3 Lifecycle Management
- **Standard → IA**: 30 days
- **IA → Glacier**: 90 days  
- **Version Cleanup**: 30 days

## 🔐 IAM Roles Created

### 1. App Runner Access Role
- **Purpose**: ECR image pulling
- **Principal**: `build.apprunner.amazonaws.com`
- **Permissions**: ECR read access

### 2. App Runner Instance Role  
- **Purpose**: Runtime application permissions
- **Principal**: `tasks.apprunner.amazonaws.com`
- **Permissions**: 
  - S3 bucket access (read/write/delete)
  - CloudWatch Logs write
  - SSM Parameter Store read

## 📊 Monitoring & Logging

### CloudWatch Integration:
- **Log Group**: `/aws/apprunner/fitness-app-service-dev`
- **Retention**: 14 days (configurable)
- **Structured Logging**: JSON format with correlation IDs

### Health Checks:
- **Endpoint**: `/health`
- **Interval**: 10 seconds
- **Timeout**: 5 seconds

## 🌐 Custom Domain Setup

1. **Set domain variable**:
   ```hcl
   custom_domain_name = "yourdomain.com"
   ```

2. **Apply Terraform**:
   ```bash
   terraform apply
   ```

3. **Add DNS records**:
   ```bash
   terraform output custom_domain_validation_records
   ```

4. **Create CNAME records** in your DNS provider using the output values.

## 🔄 CI/CD Integration

### Environment Variables for CI/CD:
```bash
# Terraform Cloud/GitHub Actions
TF_VAR_database_uri="mongodb+srv://..."
TF_VAR_jwt_secret="your-jwt-secret"
TF_VAR_ecr_image_tag="v1.2.3"
```

### Deployment Pipeline:
1. **Build & Push**: Docker image to ECR
2. **Update Tag**: Set `ecr_image_tag` variable
3. **Deploy**: `terraform apply`
4. **Verify**: Check health endpoint

## 🛠️ Troubleshooting

### Common Issues:

#### 1. S3 Access Denied
```bash
# Check IAM role attachment
aws iam list-attached-role-policies --role-name fitness-app-apprunner-instance-role-dev
```

#### 2. App Runner Service Failed
```bash
# Check logs
aws logs describe-log-groups --log-group-name-prefix "/aws/apprunner/fitness-app"
```

#### 3. ECR Pull Errors
```bash
# Verify ECR permissions
aws ecr describe-repositories --repository-names fitness-app-backend-dev
```

### Debug Commands:
```bash
# View current deployment
terraform show

# Check outputs
terraform output

# Validate configuration
terraform validate
```

## 🔒 Security Best Practices

### ✅ Implemented:
- No hardcoded credentials
- Instance profile authentication
- Encrypted S3 storage
- Private bucket with pre-signed URLs
- Least privilege IAM policies
- VPC isolation (App Runner managed)

### 🔄 Recommended Additions:
- AWS Secrets Manager for sensitive config
- CloudTrail for audit logging
- AWS Config for compliance monitoring
- VPC endpoints for private communication

## 📈 Cost Optimization

### Current Setup:
- **App Runner**: Pay per use (CPU/Memory/Requests)
- **S3**: Lifecycle policies reduce storage costs
- **ECR**: Image lifecycle policies limit storage
- **CloudWatch**: 14-day log retention

### Cost Monitoring:
```bash
# View estimated costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

## 🆘 Support

### Useful Commands:
```bash
# Check App Runner service status
aws apprunner describe-service --service-arn $(terraform output -raw app_runner_service_arn)

# View recent logs
aws logs tail /aws/apprunner/fitness-app-service-dev --follow

# Test health endpoint
curl $(terraform output -raw app_runner_service_url)/health
```

### Resources:
- [AWS App Runner Documentation](https://docs.aws.amazon.com/apprunner/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
