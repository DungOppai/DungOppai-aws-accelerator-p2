terraform {
  backend "s3" {
    bucket         = "YOUR_S3_BUCKET_NAME" # Replace with your actual S3 bucket name
    key            = "final-project/terraform.tfstate"
    region         = "us-east-1"          # Replace with your actual region
    dynamodb_table = "terraform-locks"    # Replace with your actual DynamoDB table
    encrypt        = true
  }
}
