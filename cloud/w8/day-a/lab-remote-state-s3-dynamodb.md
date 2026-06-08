# Lab: Remote State with S3 + DynamoDB Lock

## Mục tiêu

Thực hành cấu hình Terraform state lưu trên AWS S3 với DynamoDB locking để tránh race condition khi nhiều người chạy Terraform cùng lúc.

**Ngữ cảnh thực tế:**
- Local state (terraform.tfstate) không an toàn cho team
- S3 + DynamoDB lock = best practice production

---

## Phần 1: Tạo S3 Bucket + DynamoDB Table (Manual Setup)

### 1.1 Tạo S3 Bucket

```bash
# Set variables
BUCKET_NAME="my-terraform-state-$(date +%s)"
AWS_REGION="us-east-1"

# Create S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION

# Enable versioning (recovery nếu state corrupt)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption (security best practice)
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "S3 bucket created: $BUCKET_NAME"
```

### 1.2 Tạo DynamoDB Table cho State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

# Verify table
aws dynamodb describe-table \
  --table-name terraform-locks \
  --region $AWS_REGION
```

---

## Phần 2: Cấu hình Terraform Backend

### 2.1 Tạo project structure

```bash
mkdir terraform-remote-state-lab
cd terraform-remote-state-lab

# Tạo thư mục
mkdir -p infrastructure/backend
mkdir -p infrastructure/dev
```

### 2.2 File backend config (infrastructure/backend/main.tf)

```hcl
# Tạo S3 bucket + DynamoDB table bằng Terraform
# (sau khi bootstrap xong, lock sẽ dùng được)

resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}

data "aws_caller_identity" "current" {}

output "s3_bucket_id" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
```

### 2.3 Backend config file (infrastructure/backend/backend.tf)

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

---

## Phần 3: Cấu hình Remote State cho Dev Environment

### 3.1 Backend config (infrastructure/dev/backend.tf)

```hcl
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "my-terraform-state-123456789"  # Replace with your account ID
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

### 3.2 Variables (infrastructure/dev/variables.tf)

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "my-app"
}
```

### 3.3 Main config (infrastructure/dev/main.tf)

```hcl
# Example: Create EC2 instance
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t2.micro"

  tags = {
    Name        = "${var.app_name}-${var.environment}"
    Environment = var.environment
  }
}

# Example: Create S3 bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.app_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.app_name}-${var.environment}"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}
```

### 3.4 Outputs (infrastructure/dev/outputs.tf)

```hcl
output "ec2_instance_id" {
  value = aws_instance.web.id
}

output "ec2_instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app_bucket.id
}
```

---

## Phần 4: Thực hành

### Step 1: Bootstrap (Tạo backend infrastructure)

```bash
# Navigate to backend folder
cd infrastructure/backend

# Initialize local backend (temporarily)
terraform init

# Review plan
terraform plan

# Create S3 + DynamoDB
terraform apply

# Note S3 bucket ID from output
# ⚠️ Save it, bạn sẽ dùng ở step 2
```

**Output ví dụ:**
```
Outputs:

dynamodb_table_name = "terraform-locks"
s3_bucket_id = "my-terraform-state-123456789"
```

### Step 2: Cấu hình Dev Environment với Remote Backend

```bash
# Navigate to dev folder
cd ../dev

# Update bucket name in backend.tf
# Thay "my-terraform-state-123456789" bằng giá trị từ step 1
vim backend.tf  # or nano, or edit directly

# Initialize with S3 backend
terraform init

# Terraform sẽ hỏi:
# Do you want to copy existing state to the new backend?
# → Chọn: yes (nếu có state cũ) hoặc no (nếu mới)
```

### Step 3: Verify Remote State

```bash
# Confirm state is in S3
aws s3 ls s3://my-terraform-state-123456789/dev/

# Should see: terraform.tfstate

# Check S3 object
aws s3api head-object \
  --bucket my-terraform-state-123456789 \
  --key dev/terraform.tfstate

# Verify DynamoDB table exists
aws dynamodb list-tables --region us-east-1 | grep terraform-locks
```

### Step 4: Plan & Apply

```bash
# Inside infrastructure/dev
terraform plan

# If everything looks good
terraform apply
```

### Step 5: Test State Locking

**Terminal 1:**
```bash
cd infrastructure/dev

# Start a long-running apply (add delay)
terraform apply -auto-approve
```

**Terminal 2 (while Terminal 1 still running):**
```bash
cd infrastructure/dev

# Try another apply
terraform plan

# Should see:
# Error: Error acquiring the state lock
# Error acquiring the state lock: ResourceConflictException: Cannot acquire lock on table...
```

→ **Nghĩa là DynamoDB lock đang hoạt động!** 🔒

### Step 6: Cleanup

```bash
# Destroy resources
terraform destroy -auto-approve

# Check S3
aws s3 ls s3://my-terraform-state-123456789/dev/

# State file vẫn còn (for recovery)

# Optional: Remove backend infrastructure
cd ../backend
terraform destroy -auto-approve
```

---

## Phần 5: Best Practices

### ✅ Làm

1. **Always enable versioning** trên S3 bucket
2. **Enable encryption** (AES256 hoặc KMS)
3. **Block public access** trên S3
4. **Use state locking** với DynamoDB
5. **Separate backend init** từ main infrastructure
6. **Document bucket + table names** cho team
7. **Use IAM roles** thay vì access keys

### ❌ Không làm

1. Commit `terraform.tfstate` vào Git
2. Chia sẻ AWS credentials qua email
3. Tắt state locking (nếu team > 1 người)
4. Để S3 bucket public
5. Không backup state

---

## Phần 6: Advanced - Terraform Backends Config File

Thay vì hardcode bucket name, dùng `-backend-config` flag:

```bash
# File: backend-config.hcl
bucket         = "my-terraform-state-123456789"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true
```

```bash
# Initialize với config file
terraform init -backend-config=backend-config.hcl
```

---

## Phần 7: Troubleshooting

| Error | Nguyên nhân | Fix |
|-------|-----------|-----|
| `NoSuchBucket` | S3 bucket không tồn tại | Kiểm tra bucket name + region |
| `AccessDenied` | IAM permissions không đủ | Thêm S3 + DynamoDB permissions |
| `ResourceConflictException` | Người khác đang chạy terraform | Chờ họ xong hoặc force unlock |
| `InvalidUserID` | DynamoDB table không tồn tại | Tạo DynamoDB table trước |

**Force unlock (nếu cần):**
```bash
terraform force-unlock LOCK_ID
```

---

## Phần 8: Learning Checkpoints

Sau lab này, bạn nên hiểu:

- [ ] Local state vs Remote state khác gì
- [ ] Tại sao cần DynamoDB lock
- [ ] Cách bootstrap backend infrastructure
- [ ] Cách migrate từ local → S3 backend
- [ ] State locking hoạt động như thế nào
- [ ] Best practices cho production

---

## References

- Terraform S3 Backend: https://www.terraform.io/language/settings/backends/s3
- State Locking: https://www.terraform.io/language/state/locking
- AWS S3 Best Practices: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html
