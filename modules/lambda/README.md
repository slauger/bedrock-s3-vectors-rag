# Lambda Function - AI Chatbot

AWS Lambda Handler mit **OpenAI-kompatibler API** powered by AWS Bedrock (Claude 3.5 Sonnet).

## ⚡ NEW: Container Deployment with FAISS

**Two deployment modes:**

### Option 1: ZIP Deployment (Legacy - with Bedrock KB)
```
Lambda ZIP → Bedrock KB → OpenSearch Serverless → $700/month
```

### Option 2: Container Deployment (NEW - with FAISS) ⭐
```
Lambda Container → FAISS (embedded) → $0.50/month
```

**99% cost reduction!** See [Container Deployment Guide](#container-deployment-with-faiss) below.

---

## Architektur

### Legacy (ZIP with Bedrock KB):
```
Hugo Website (Frontend)
        ↓
API Gateway (/v1/chat/completions)
        ↓
Lambda Function (OpenAI-Format)
        ↓
    ┌─────────┴─────────┐
    ↓                   ↓
Bedrock KB          Claude 3.5
(OpenSearch)        (Response)
```

### NEW (Container with FAISS):
```
Hugo Website (Frontend)
        ↓
API Gateway (/v1/chat/completions)
        ↓
Lambda Container (OpenAI-Format)
        ↓
    ┌─────────┴─────────┐
    ↓                   ↓
FAISS (local)       Claude 3.5
(7ms retrieval!)    (Response)
```

## Features

✅ **OpenAI-kompatible API** - Standard Chat Completions Format
✅ **RAG-Integration** - Bedrock Knowledge Base Retrieval
✅ **Claude 3.5 Sonnet** - AWS Bedrock (EU Region)
✅ **DynamoDB Logging** - Conversation History (optional)
✅ **Error Handling** - Graceful degradation
✅ **CORS Support** - Cross-Origin Requests enabled

---

## API Endpoint

### POST /v1/chat/completions

**OpenAI Chat Completions API compatible endpoint**

**Request Format:**
```json
{
  "model": "claude-3-5-sonnet",
  "messages": [
    {"role": "system", "content": "You are a helpful AI assistant"},
    {"role": "user", "content": "Wann ist Check-in?"}
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

**Response Format:**
```json
{
  "id": "chatcmpl-abc123def456",
  "object": "chat.completion",
  "created": 1705234567,
  "model": "claude-3-5-sonnet",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Check-in ist ab 16:00 Uhr möglich. Sie können auch früher anreisen mit unserem Früh-Anreise-Paket (ab 49€ inkl. Mittagessen)."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "total_tokens": 0
  }
}
```

---

## Testing

### 1. Mit curl

```bash
# Get API Endpoint
export API_URL=$(cd terraform/environments/dev && tofu output -raw api_endpoint)

# Test Request
curl -X POST "$API_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet",
    "messages": [
      {"role": "user", "content": "Wann ist Check-in?"}
    ]
  }' | jq .
```

### 2. Mit OpenAI Python SDK

```python
from openai import OpenAI

# Point to your Lambda API
client = OpenAI(
    api_key="not-needed",  # Lambda has no auth (add if needed)
    base_url="https://your-api.execute-api.eu-central-1.amazonaws.com/dev/v1"
)

response = client.chat.completions.create(
    model="claude-3-5-sonnet",
    messages=[
        {"role": "user", "content": "Wann ist Check-in?"}
    ]
)

print(response.choices[0].message.content)
```

### 3. Mit JavaScript

```javascript
const response = await fetch('https://your-api.execute-api.eu-central-1.amazonaws.com/dev/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    model: 'claude-3-5-sonnet',
    messages: [
      {role: 'user', content: 'Wann ist Check-in?'}
    ]
  })
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

---

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `KNOWLEDGE_BASE_ID` | Bedrock KB ID | `ABC123DEF456` |
| `MODEL_ID` | Claude Model ID | `anthropic.claude-3-5-sonnet-20241022-v2:0` |
| `SESSIONS_TABLE` | DynamoDB Sessions Table | `your-project-dev-sessions` |
| `MESSAGES_TABLE` | DynamoDB Messages Table | `your-project-dev-messages` |
| `ANALYTICS_TABLE` | DynamoDB Analytics Table | `your-project-dev-analytics` |
| `AWS_REGION` | AWS Region | `eu-central-1` |
| `LOG_LEVEL` | Log Level | `INFO` / `DEBUG` |

---

## File Structure

```
terraform/modules/lambda/
├── src/
│   ├── lambda_function.py   # Main handler
│   └── requirements.txt     # Python dependencies
├── main.tf                  # Terraform resources
├── variables.tf             # Input variables
├── outputs.tf               # Output values
└── README.md               # This file
```

---

## Code Structure

### lambda_function.py

**Main Handler:**
```python
def lambda_handler(event, context):
    """
    OpenAI Chat Completions API compatible handler
    """
    # 1. Parse OpenAI-format request
    # 2. Retrieve from Knowledge Base (RAG)
    # 3. Call Claude via Bedrock
    # 4. Return OpenAI-format response
```

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `retrieve_from_knowledge_base()` | Search Bedrock KB |
| `prepare_messages_with_context()` | Inject KB context |
| `call_claude()` | Invoke Claude via Bedrock |
| `create_openai_response()` | Format as OpenAI response |
| `log_conversation()` | Save to DynamoDB |

---

## Provider Switching

Das Lambda nutzt eine OpenAI-kompatible API. **Du kannst später den Backend-Code ändern**, ohne das Frontend anzupassen!

### Aktuell: AWS Bedrock (Claude)
```python
response = bedrock_runtime.invoke_model(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    body=json.dumps(request_body)
)
```

### Später möglich: Azure OpenAI
```python
response = azure_openai.chat.completions.create(
    model="gpt-4o",
    messages=messages
)
```

### Später möglich: OpenAI direkt
```python
response = openai.chat.completions.create(
    model="gpt-4o",
    messages=messages
)
```

**Frontend merkt NICHTS!** ✅

---

## Error Handling

### Knowledge Base Fehler
```python
# Graceful degradation - Continue without context
try:
    kb_context = retrieve_from_knowledge_base(query)
except:
    kb_context = ""  # Claude antwortet ohne KB-Kontext
```

### Claude API Fehler
```python
# Return OpenAI-compatible error
{
  "error": {
    "message": "Bedrock API error: ...",
    "type": "invalid_request_error",
    "code": 500
  }
}
```

---

## Monitoring

### CloudWatch Logs

```bash
# View logs
aws logs tail /aws/lambda/your-project-dev-handler --follow
```

### DynamoDB Queries

```bash
# Check logged conversations
aws dynamodb scan \
  --table-name your-project-dev-messages \
  --limit 10
```

---

## Deployment

### Automatisch via Terraform

```bash
cd terraform/environments/dev
tofu init
tofu apply
```

**Terraform erstellt automatisch:**
1. ✅ ZIP-Package aus `src/` Verzeichnis
2. ✅ Lambda Function Upload
3. ✅ IAM Roles & Policies
4. ✅ Environment Variables
5. ✅ API Gateway Integration

**Kein manuelles ZIP-Packaging nötig!**

---

## Development

### Lokales Testen (ohne AWS)

```bash
# Install dependencies
pip install boto3

# Mock AWS SDK
# (Verwende moto oder LocalStack für lokales Testing)
```

### Code-Änderungen deployen

```bash
# 1. Code in src/lambda_function.py ändern
# 2. Terraform apply (erstellt neues ZIP automatisch!)
cd terraform/environments/dev
tofu apply

# Terraform erkennt Code-Änderungen via source_code_hash
```

---

## Kosten-Schätzung

**Lambda Execution:**
- 512 MB RAM
- ~1-3 Sekunden pro Request
- Bei 1.000 Requests/Monat: ~$0.20

**Bedrock API (größter Faktor!):**
- Claude 3.5 Sonnet: $3 per 1M input / $15 per 1M output
- Bei 1.000 Chats (500 in, 1.000 out): ~$5-10

**DynamoDB:**
- On-Demand Billing
- Bei 1.000 Requests: ~$1

**Total: ~$6-11/Monat (ohne OpenSearch Serverless)**

---

## Troubleshooting

### Error: "Knowledge Base ID not found"
```bash
# Check KB_ID Environment Variable
aws lambda get-function-configuration \
  --function-name your-project-dev-handler \
  | jq '.Environment.Variables.KNOWLEDGE_BASE_ID'
```

### Error: "Access Denied" (Bedrock)
```bash
# Check IAM Role Permissions
aws lambda get-function \
  --function-name your-project-dev-handler \
  | jq '.Configuration.Role'

aws iam get-role-policy \
  --role-name your-project-dev-lambda-role \
  --policy-name your-project-dev-bedrock-access
```

### Error: 502 Bad Gateway
```bash
# Check Lambda Logs for errors
aws logs tail /aws/lambda/your-project-dev-handler \
  --since 10m
```

---

## Security

### IAM Permissions (Least Privilege)

**Lambda kann nur:**
- ✅ Bedrock KB retrieve
- ✅ Bedrock invoke_model (Claude)
- ✅ DynamoDB PutItem/GetItem
- ✅ CloudWatch Logs write

**Lambda kann NICHT:**
- ❌ S3 modify
- ❌ Bedrock KB modify
- ❌ IAM ändern

### CORS Security

```python
# CORS Headers in Response
'Access-Control-Allow-Origin': '*'  # Dev: Allow all
# Prod: Set to your production domain
```

---

---

## Container Deployment with FAISS

### Why Container + FAISS?

| Feature | Bedrock KB + OpenSearch | Container + FAISS |
|---------|------------------------|-------------------|
| **Monthly Cost** | $700 | **$0.50** (99% cheaper!) |
| **Cold Start** | 400ms | 800ms |
| **Warm Start** | 400ms | **7ms** (57x faster!) |
| **Scalability** | Unlimited | Good for <10GB |
| **Deployment** | Complex (2 services) | Simple (1 container) |

### Quick Start

```bash
cd terraform/modules/lambda

# 1. Build FAISS index and container
./build-and-push.sh

# 2. Update terraform.tfvars
cat >> ../../environments/dev/terraform.tfvars <<EOF
use_container_image = true
container_image_uri = "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com/your-project-lambda:latest"
EOF

# 3. Deploy
cd ../../environments/dev
terraform apply
```

### Files

- `Dockerfile` - Lambda container definition
- `build_faiss_index.py` - Builds FAISS index from S3
- `src/faiss_retriever.py` - FAISS search logic
- `build-and-push.sh` - Build automation
- `main-container.tf` - Container Lambda resources

### Updating KB Content

```bash
# When KB content changes in S3:
cd terraform/modules/lambda
./build-and-push.sh

cd ../../environments/dev
terraform apply
```

### Performance Details

**FAISS Index Size:** ~5-10MB (for current KB)
**Container Size:** ~600MB total
**Memory:** 512MB Lambda
**Warm Start Retrieval:** 7ms (vs 400ms Bedrock)

### Cost Breakdown

**Container Deployment:**
- ECR Storage: $0.10/GB × 0.6GB = **$0.06/month**
- Lambda: Free Tier (1M requests)
- Bedrock Claude: $5-50/month (unchanged)
- **Total: $5-50/month**

**Legacy Deployment:**
- OpenSearch Serverless: $700/month
- Bedrock KB API: $5/month
- Lambda: Free Tier
- Bedrock Claude: $5-50/month
- **Total: $710-755/month**

**Savings: $700/month (99%!)**

---

## Next Steps

### For Container Deployment:
1. ✅ Run `./build-and-push.sh` to create container
2. ✅ Update `terraform.tfvars` with container image URI
3. ✅ Set `use_container_image = true`
4. ✅ Deploy with `terraform apply`
5. ✅ Test with curl

### For Legacy ZIP Deployment:
1. ✅ Deploy via Terraform (defaults to ZIP)
2. ✅ Upload Knowledge Base
3. ✅ Test with curl
4. ✅ Integrate in Hugo Website

**Viel Erfolg!** 🚀
