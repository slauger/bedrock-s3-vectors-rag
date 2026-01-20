# AWS Bedrock S3 Vectors RAG

Terraform modules for deploying a production-ready RAG (Retrieval-Augmented Generation) chatbot using **AWS S3 Vectors** for semantic search and **Amazon Bedrock** for LLM inference.

## Key Features

- **S3 Vectors Integration** - Native AWS vector search (no external vector DB needed)
- **Amazon Bedrock** - Serverless LLM inference (Claude 3.5 Sonnet)
- **Serverless Architecture** - Lambda + API Gateway + DynamoDB
- **ZIP Deployment** - Simple deployment without Docker complexity
- **Modular Design** - Reusable Terraform modules
- **Production Ready** - Monitoring, logging, rate limiting included

## What is S3 Vectors?

S3 Vectors is AWS's managed vector search capability (launched late 2025) that enables semantic search directly on S3 buckets. Key benefits:

- No separate vector database infrastructure
- Integrated with S3 storage
- Pay-per-query pricing
- Automatic index management
- Supports multiple embedding models

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ API Gateway │ (REST API + Rate Limiting)
└──────┬──────┘
       │
       ▼
┌─────────────┐       ┌──────────────┐
│   Lambda    │──────▶│  S3 Vectors  │ (Semantic Search)
│  (Python)   │       │    Index     │
└──────┬──────┘       └──────────────┘
       │                      │
       │                      ▼
       ▼               ┌──────────────┐
┌─────────────┐       │  S3 Bucket   │ (Knowledge Base Data)
│   Bedrock   │       │  (Documents) │
│  (Claude)   │       └──────────────┘
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  DynamoDB   │ (Sessions, Messages, Analytics)
└─────────────┘
```

## Quick Start

### Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.0
3. AWS CLI configured
4. Python 3.12+ (for S3 Vectors index building)
5. boto3 >= 1.39.9 (for S3 Vectors support)

### Basic Deployment

```bash
# Clone the repository
git clone https://github.com/slauger/bedrock-s3-vectors-rag.git
cd bedrock-s3-vectors-rag/examples/basic

# Configure your deployment
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project name

# Deploy infrastructure
terraform init
terraform plan
terraform apply

# Get your API endpoint
terraform output api_endpoint
```

### Upload Knowledge Base Data

```bash
# Upload your documents to S3
aws s3 cp ./knowledge-base/ s3://my-chatbot-kb-data/website/ --recursive
```

### Build S3 Vectors Index

```bash
# Install dependencies
cd ../../modules/lambda
pip3 install boto3>=1.40.4

# Build the vector index
python3 build_s3_vectors_index.py \
  --bucket my-chatbot-vector-bucket \
  --kb-bucket my-chatbot-kb-data \
  --kb-prefix website/ \
  --index-name kb-index

# This will:
# 1. Read all documents from S3
# 2. Generate embeddings using Bedrock
# 3. Create S3 Vectors index
# 4. Upload vectors to index
```

### Test the Chatbot

```bash
# Test via curl
curl -X POST "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What can you help me with?",
    "session_id": "test-123"
  }'
```

## Modules

### Lambda Module

Serverless chatbot handler with S3 Vectors integration.

**Features:**
- ZIP-based deployment (no Docker required)
- S3 Vectors retrieval
- Bedrock LLM inference
- DynamoDB session management
- CloudWatch logging

**Usage:**
```hcl
module "lambda" {
  source = "./modules/lambda"

  project_name            = "my-chatbot"
  s3_vectors_bucket_name  = "my-vectors-bucket"
  s3_vectors_index_name   = "kb-index"
  bedrock_embed_model     = "amazon.titan-embed-text-v2:0"
  model_id                = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  # ... other config
}
```

### API Gateway Module

REST API with rate limiting and CORS support.

**Features:**
- API Gateway REST API
- Usage plans and API keys
- Rate limiting (burst + sustained)
- CORS configuration
- CloudWatch access logs

**Usage:**
```hcl
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name      = "my-chatbot"
  lambda_invoke_arn = module.lambda.invoke_arn
  burst_limit       = 20
  rate_limit        = 10
  cors_allow_origin = "'https://example.com'"
}
```

### S3 Module

S3 buckets for knowledge base data and vectors.

**Features:**
- KB data bucket with versioning
- Vector storage bucket
- Encryption at rest (AES256)
- Lifecycle policies
- Optional website hosting bucket

**Usage:**
```hcl
module "s3" {
  source = "./modules/s3"

  project_name         = "my-chatbot"
  vector_bucket_name   = "my-vectors"
  kb_data_bucket_name  = "my-kb-data"
  create_website_bucket = false
}
```

### DynamoDB Module

Session and message storage.

**Features:**
- Sessions table (conversation state)
- Messages table (chat history)
- Analytics table (usage metrics)
- TTL for automatic cleanup
- Optional Point-in-Time Recovery

**Usage:**
```hcl
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = "my-chatbot"
  enable_pitr  = true
}
```

### Monitoring Module

CloudWatch alarms and dashboards.

**Features:**
- Lambda error rate alarms
- API Gateway 4xx/5xx alarms
- DynamoDB throttle alarms
- SNS email notifications
- Custom CloudWatch dashboard

**Usage:**
```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name         = "my-chatbot"
  lambda_function_name = module.lambda.function_name
  alarm_email          = "ops@example.com"
}
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
log_level           = "INFO"
```

## Cost Estimates

Approximate monthly costs for moderate usage (us-east-1):

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 10K requests (512MB, 30s avg) | ~$0.20 |
| API Gateway | 10K requests | ~$0.035 |
| DynamoDB | 100K read/write units | ~$1.25 |
| S3 Storage | 10 GB | ~$0.23 |
| S3 Vectors Queries | 10K queries | ~$0.50 |
| Bedrock (Claude 3.5) | 1M input + 500K output tokens | ~$6.00 |
| **Total** | | **~$8-10/month** |

For production workloads (100K requests/month): **~$50-100/month**

## S3 Vectors vs Other Vector DBs

| Feature | S3 Vectors | Pinecone | Weaviate | OpenSearch |
|---------|-----------|----------|----------|------------|
| Setup Complexity | ⭐⭐⭐⭐⭐ Low | ⭐⭐⭐ Medium | ⭐⭐ High | ⭐ Very High |
| AWS Integration | ✅ Native | ❌ External | ❌ External | ⚠️ AWS Service |
| Pricing Model | Pay-per-query | Monthly subscription | Self-hosted | Instance-based |
| Serverless | ✅ Yes | ⚠️ Partial | ❌ No | ❌ No |
| Maintenance | ⭐⭐⭐⭐⭐ None | ⭐⭐⭐ Low | ⭐⭐ Medium | ⭐ High |
| Latency | ~100-200ms | ~50-100ms | ~50-100ms | ~50-100ms |

**S3 Vectors is ideal when:**
- You want minimal infrastructure complexity
- Your data is already in S3
- You need serverless scaling
- Cost predictability is important
- You don't need sub-50ms latency

## Examples

### Basic Example

Simple deployment with all defaults.

📁 [examples/basic/](./examples/basic/)

### Advanced Example (Coming Soon)

Production deployment with:
- Custom VPC
- Enhanced monitoring
- Multi-region failover
- WAF integration

## CI/CD

### GitHub Actions

The project includes automated validation:

**Terraform Validation Pipeline** (`.github/workflows/terraform-validation.yml`)
- `tofu fmt -check` - Format validation
- `tflint` - Terraform linting (all modules + examples)
- `tofu validate` - Syntax validation

Runs on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Status Badge:**
```markdown
![Terraform Validation](https://github.com/slauger/bedrock-s3-vectors-rag/actions/workflows/terraform-validation.yml/badge.svg)
```

## Development

### Code Quality

Before committing, run:

```bash
# Format all Terraform files
tofu fmt -recursive

# Run TFLint on all modules
for dir in modules/*/ examples/*/; do
  echo "Linting $dir..."
  (cd "$dir" && tflint --init && tflint)
done
```

### Building S3 Vectors Index Locally

```bash
cd modules/lambda
python3 build_s3_vectors_index.py \
  --bucket my-vectors \
  --kb-bucket my-kb-data \
  --kb-prefix website/ \
  --index-name kb-index \
  --batch-size 100
```

### Testing Lambda Function Locally

```bash
cd modules/lambda/src
python3 -c "
from lambda_function import lambda_handler
event = {
    'body': '{\"message\": \"Hello\", \"session_id\": \"test\"}'
}
result = lambda_handler(event, None)
print(result)
"
```

## Troubleshooting

### S3 Vectors Index Not Found

```python
# Check if index exists
import boto3
s3 = boto3.client('s3')
response = s3.head_vector_index(
    Bucket='my-vectors',
    Index='kb-index'
)
print(response)
```

### Lambda Timeout Errors

Increase timeout and memory:
```hcl
lambda_timeout     = 60
lambda_memory_size = 1024
```

### API Gateway 429 (Rate Limit)

Adjust rate limits:
```hcl
api_burst_limit = 50
api_rate_limit  = 25
```

## Roadmap

- [ ] Multi-region deployment example
- [ ] Streaming response support
- [ ] Web UI example (React/Next.js)
- [ ] Advanced RAG techniques (HyDE, multi-query)
- [ ] Custom embedding model support
- [ ] Automated KB sync from GitHub/S3

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/slauger/bedrock-s3-vectors-rag/issues)
- **Discussions**: [GitHub Discussions](https://github.com/slauger/bedrock-s3-vectors-rag/discussions)
- **Documentation**: [Wiki](https://github.com/slauger/bedrock-s3-vectors-rag/wiki)

## Credits

Built with:
- [AWS Bedrock](https://aws.amazon.com/bedrock/)
- [S3 Vectors](https://aws.amazon.com/s3/features/vectors/)
- [Terraform](https://www.terraform.io/)
- [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

## Related Projects

- [LangChain](https://github.com/langchain-ai/langchain) - LLM application framework
- [AWS Samples](https://github.com/aws-samples) - Official AWS examples
- [Bedrock Claude Chat](https://github.com/aws-samples/bedrock-claude-chat) - Another Bedrock chatbot example

---

**Made with ❤️ for the AWS community**
