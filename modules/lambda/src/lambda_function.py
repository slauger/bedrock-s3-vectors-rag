"""
AWS Lambda Handler for AI Chatbot
OpenAI-compatible API endpoint powered by AWS Bedrock (Claude 3.5 Sonnet)
Knowledge retrieval powered by AWS S3 Vectors (managed vector search)
"""

import json
import os
import uuid
import time
from datetime import datetime
from typing import Dict, List, Any
import boto3
from botocore.exceptions import ClientError

# Import S3 Vectors retriever
from s3_vectors_retriever import retrieve_context

# Environment Variables
MODEL_ID = os.environ['MODEL_ID']
SESSIONS_TABLE = os.environ.get('SESSIONS_TABLE', '')
MESSAGES_TABLE = os.environ.get('MESSAGES_TABLE', '')
ANALYTICS_TABLE = os.environ.get('ANALYTICS_TABLE', '')
AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

# AWS Clients
bedrock_runtime = boto3.client('bedrock-runtime', region_name=AWS_REGION)
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION) if SESSIONS_TABLE else None


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler - OpenAI Chat Completions API compatible

    Endpoint: POST /v1/chat/completions
    Request Format: OpenAI Chat Completions API
    Response Format: OpenAI Chat Completions API
    """
    try:
        # Parse request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event

        # Extract OpenAI-format parameters
        messages = body.get('messages', [])
        model = body.get('model', 'claude-3-5-sonnet')
        temperature = body.get('temperature', 0.7)
        max_tokens = body.get('max_tokens', 2000)

        # Validate
        if not messages:
            return error_response(400, "messages field is required")

        # Extract user query
        user_message = next((m for m in reversed(messages) if m['role'] == 'user'), None)
        if not user_message:
            return error_response(400, "No user message found")

        # 1. Build conversation-aware query for Knowledge Base
        query = build_contextual_query(messages, max_messages=5)
        print(f"[INFO] Retrieving context for conversation query ({len(query)} chars)...")

        # Retrieve context from S3 Vectors
        kb_context = retrieve_context(query, max_results=5)

        # 2. Prepare messages with context
        enhanced_messages = prepare_messages_with_context(messages, kb_context)

        # 3. Call Claude via Bedrock
        print(f"[INFO] Calling Claude with {len(enhanced_messages)} messages...")
        claude_response = call_claude(enhanced_messages, temperature, max_tokens)

        # 4. Log analytics to DynamoDB (optional, DSGVO-compliant)
        # NOTE: Only stores statistical data (lengths, timestamps), NO PII!
        if dynamodb:
            log_conversation(user_message['content'], claude_response, kb_context)

        # 5. Return OpenAI-compatible response
        response = create_openai_response(claude_response, model)

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"[ERROR] Lambda handler error: {str(e)}")
        import traceback
        traceback.print_exc()
        return error_response(500, f"Internal server error: {str(e)}")


def build_contextual_query(messages: List[Dict], max_messages: int = 5) -> str:
    """
    Build conversation-aware query for Knowledge Base retrieval

    Takes the last N messages from the conversation to provide context
    for better KB retrieval results. This helps with follow-up questions
    like "And the times?" which need context from previous messages.

    Args:
        messages: Full conversation history
        max_messages: How many recent messages to include (default: 5)

    Returns:
        Query string with conversation context
    """
    # Take last N messages (or all if fewer)
    recent = messages[-max_messages:] if len(messages) > max_messages else messages

    # Format as conversation for KB
    query_parts = []
    for msg in recent:
        role = msg.get('role', '')
        content = msg.get('content', '')

        # Skip system messages
        if role == 'system' or not content:
            continue

        # Format: "User: question" or "Assistant: answer"
        if role == 'user':
            query_parts.append(f"User: {content}")
        elif role == 'assistant':
            # Truncate assistant responses to keep query shorter
            truncated = content[:200] + '...' if len(content) > 200 else content
            query_parts.append(f"Assistant: {truncated}")

    query = "\n".join(query_parts)

    # Fallback: if no valid messages, use last user message
    if not query:
        user_message = next((m for m in reversed(messages) if m.get('role') == 'user'), None)
        query = user_message.get('content', 'Hello') if user_message else 'Hello'

    return query


# Note: retrieve_from_knowledge_base() removed - now using FAISS via faiss_retriever.py


def prepare_messages_with_context(messages: List[Dict], context: str) -> List[Dict]:
    """
    Enhance messages with Knowledge Base context
    """
    enhanced = messages.copy()

    # Find or create system message
    system_idx = next((i for i, m in enumerate(enhanced) if m['role'] == 'system'), None)

    if context:
        context_instruction = f"""
You are a helpful AI assistant with access to a knowledge base.

CRITICAL RULES:
1. NEVER invent information that is not in the context!
2. ONLY answer based on the provided information
3. If information is not available, say: "I don't have that information in my knowledge base."

SPECIAL COMMAND: If the user asks for "knowledge base version" or "KB version", respond with: "The current knowledge base version is: {os.environ.get('KB_VERSION', 'unknown')}"

Here is relevant information from the knowledge base:

{context}

Answer ONLY based on the provided information. Use it to answer questions, but never mention the "knowledge base" or that the information comes from a database.

IF information is NOT in context:
"I don't have that specific information available."

Format your responses with Markdown for better readability (bold, lists, etc.).
""".strip()

        if system_idx is not None:
            # Append to existing system message
            enhanced[system_idx]['content'] += "\n\n" + context_instruction
        else:
            # Insert new system message at beginning
            enhanced.insert(0, {
                'role': 'system',
                'content': context_instruction
            })

    return enhanced


def call_claude(messages: List[Dict], temperature: float, max_tokens: int) -> str:
    """
    Call LLM via Bedrock Converse API (works for Claude, Nova, etc.)
    """
    # Separate system message
    system_prompts = []
    converse_messages = []

    for msg in messages:
        if msg['role'] == 'system':
            system_prompts.append({'text': msg['content']})
        else:
            converse_messages.append({
                'role': msg['role'],
                'content': [{'text': msg['content']}]
            })

    # Prepare Converse API request
    converse_params = {
        'modelId': MODEL_ID,
        'messages': converse_messages,
        'inferenceConfig': {
            'maxTokens': max_tokens,
            'temperature': temperature
        }
    }

    if system_prompts:
        converse_params['system'] = system_prompts

    # Call Bedrock Converse API
    try:
        response = bedrock_runtime.converse(**converse_params)

        # Extract text from response
        output_message = response['output']['message']
        text = ''.join([block['text'] for block in output_message['content'] if 'text' in block])

        print(f"[INFO] Model response: {len(text)} chars")
        return text

    except ClientError as e:
        error_msg = f"Bedrock API error: {str(e)}"
        print(f"[ERROR] {error_msg}")
        raise RuntimeError(error_msg)


def create_openai_response(text: str, model: str) -> Dict[str, Any]:
    """
    Create OpenAI-compatible Chat Completion response
    """
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": text
                },
                "finish_reason": "stop"
            }
        ],
        "usage": {
            "prompt_tokens": 0,  # Bedrock doesn't provide token counts
            "completion_tokens": 0,
            "total_tokens": 0
        }
    }


def log_conversation(query: str, response: str, context: str):
    """
    Log analytics metrics to DynamoDB (DSGVO-compliant - no PII!)

    Stores only statistical data:
    - Query/response length (character counts)
    - Context usage (KB chunks retrieved)
    - Timestamp for time-series analysis

    Does NOT store:
    - Actual query/response text
    - User identifiable information
    - Personal data
    """
    try:
        if not MESSAGES_TABLE:
            return

        table = dynamodb.Table(MESSAGES_TABLE)

        timestamp = datetime.utcnow().isoformat()
        message_id = str(uuid.uuid4())
        session_id = str(uuid.uuid4())  # Generate session ID

        # Analytics-only: NO PII!
        table.put_item(Item={
            'session_id': session_id,  # Required partition key
            'message_id': message_id,
            'timestamp': timestamp,
            # Statistical data only
            'query_length': len(query),
            'response_length': len(response),
            'context_used': bool(context),
            'context_length': len(context),
            'ttl': int(time.time()) + (30 * 24 * 60 * 60)  # 30 days TTL
        })

        print(f"[INFO] Logged analytics to DynamoDB: {message_id}")

    except Exception as e:
        print(f"[WARNING] Failed to log to DynamoDB: {str(e)}")
        # Don't fail the request if logging fails


def error_response(status_code: int, message: str) -> Dict[str, Any]:
    """
    Create error response (OpenAI-compatible format)
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'error': {
                'message': message,
                'type': 'invalid_request_error',
                'code': status_code
            }
        })
    }
