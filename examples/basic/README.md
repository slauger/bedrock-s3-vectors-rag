# Basic Example - S3 Vectors RAG with AWS Bedrock

This example deploys a complete RAG (Retrieval-Augmented Generation) chatbot using:
- AWS Lambda (ZIP deployment)
- S3 Vectors for semantic search
- Amazon Bedrock for LLM inference
- API Gateway for REST API
- DynamoDB for session/message storage

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **Knowledge Base Data** uploaded to S3
5. **S3 Vectors Index** created (see below)

## Quick Start

### 1. Clone and Configure

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Upload Knowledge Base Data

```bash
# Upload your documents to the KB data bucket
aws s3 cp ./knowledge-base/ s3://my-chatbot-kb-data/website/ --recursive
```

### 4. Build S3 Vectors Index

```bash
# Use the build script from the lambda module
cd ../../modules/lambda
python3 build_s3_vectors_index.py \
  --bucket my-chatbot-vector-bucket \
  --kb-bucket my-chatbot-kb-data \
  --kb-prefix website/ \
  --index-name kb-index
```

### 5. Test the API

```bash
# Get the API endpoint
API_URL=$(terraform output -raw api_endpoint)

# Test the chatbot
curl -X POST "${API_URL}/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, what can you help me with?",
    "session_id": "test-session"
  }'
```

## Configuration

### Minimal Configuration

```hcl
# terraform.tfvars
project_name = "my-chatbot"
aws_region   = "us-east-1"
```

### Production Configuration

```hcl
# terraform.tfvars
project_name        = "prod-chatbot"
aws_region          = "us-east-1"
bedrock_model_id    = "anthropic.claude-3-5-sonnet-20241022-v2:0"
lambda_timeout      = 60
lambda_memory_size  = 1024
enable_pitr         = true
enable_monitoring   = true
alarm_email         = "ops@example.com"
api_burst_limit     = 50
api_rate_limit      = 25
```

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ API Gateway │ (REST API)
└──────┬──────┘
       │
       ▼
┌─────────────┐       ┌──────────────┐
│   Lambda    │──────▶│  S3 Vectors  │ (Semantic Search)
│  (Python)   │       │    Index     │
└──────┬──────┘       └──────────────┘
       │                      │
       │                      │
       ▼                      ▼
┌─────────────┐       ┌──────────────┐
│   Bedrock   │       │  S3 Bucket   │ (KB Data)
│  (Claude)   │       │  (Documents) │
└──────┬──────┘       └──────────────┘
       │
       ▼
┌─────────────┐
│  DynamoDB   │ (Sessions, Messages, Analytics)
└─────────────┘
```

## Outputs

After deployment, you'll get:

- `api_endpoint` - Your chatbot API URL
- `lambda_function_name` - Lambda function name for debugging
- `vector_bucket_name` - S3 bucket for vectors
- `kb_data_bucket_name` - S3 bucket for KB data
- `sessions_table_name` - DynamoDB sessions table
- `messages_table_name` - DynamoDB messages table
- `analytics_table_name` - DynamoDB analytics table

## Costs

Approximate monthly costs (us-east-1):

- **Lambda**: ~$0.20 per 1M requests (512MB, 30s avg)
- **API Gateway**: ~$3.50 per 1M requests
- **DynamoDB**: ~$1.25 per 1M read/write units (on-demand)
- **S3**: ~$0.023 per GB storage + ~$0.005 per 10K requests
- **Bedrock**: ~$3.00 per 1M input tokens, ~$15.00 per 1M output tokens (Claude 3.5 Sonnet)

**Estimated**: ~$20-50/month for moderate usage (10K requests/month)

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

### Lambda errors

```bash
# View logs
aws logs tail /aws/lambda/my-chatbot-handler --follow
```

### S3 Vectors not working

```bash
# Check index exists
python3 -c "
import boto3
s3 = boto3.client('s3')
resp = s3.head_vector_index(
    Bucket='my-chatbot-vector-bucket',
    Index='kb-index'
)
print(resp)
"
```

### API Gateway 5xx errors

```bash
# Check Lambda permissions
aws lambda get-policy --function-name my-chatbot-handler
```

## Next Steps

- Add monitoring: Set `enable_monitoring = true`
- Enable PITR backups: Set `enable_pitr = true`
- Customize CORS: Update `cors_allow_origin`
- Add authentication: Integrate API Gateway authorizers
- Scale up: Increase `lambda_memory_size` and timeout

## Support

For issues or questions:
- GitHub Issues: [bedrock-s3-vectors-rag](https://github.com/slauger/bedrock-s3-vectors-rag)
- Documentation: See main [README.md](../../README.md)
