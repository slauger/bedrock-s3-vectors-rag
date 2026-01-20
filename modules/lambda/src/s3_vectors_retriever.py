"""
S3 Vectors-based Knowledge Base Retrieval
Replaces FAISS with AWS S3 Vectors API - much simpler, no ML dependencies!
"""

import os
import json
from typing import List, Dict
import boto3
from botocore.exceptions import ClientError

# Configuration
VECTOR_BUCKET = os.environ.get('S3_VECTORS_BUCKET', 'your-project-dev-vector-bucket')
VECTOR_INDEX = os.environ.get('S3_VECTORS_INDEX', 'kb-index')
BEDROCK_EMBED_MODEL = os.environ.get('BEDROCK_EMBED_MODEL', 'amazon.titan-embed-text-v2:0')
MAX_RESULTS = int(os.environ.get('MAX_VECTOR_RESULTS', '5'))
AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')

# AWS Clients
s3vectors_client = boto3.client('s3vectors', region_name=AWS_REGION)
bedrock_runtime = boto3.client('bedrock-runtime', region_name=AWS_REGION)


def _generate_query_embedding(query: str) -> List[float]:
    """
    Generate embedding for query using Bedrock Titan

    Args:
        query: User query text

    Returns:
        List of floats representing the query embedding
    """
    try:
        print(f"[INFO] Generating embedding for query ({len(query)} chars)")

        # Call Bedrock Titan Embed API
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_EMBED_MODEL,
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                'inputText': query
            })
        )

        # Parse response
        response_body = json.loads(response['body'].read())
        embedding = response_body['embedding']

        print(f"[INFO] Generated {len(embedding)}-dimensional embedding")
        return embedding

    except Exception as e:
        print(f"[ERROR] Failed to generate embedding: {e}")
        raise


def retrieve_context(query: str, max_results: int = MAX_RESULTS) -> str:
    """
    Retrieve relevant context from S3 Vectors index

    Args:
        query: User query text
        max_results: Number of results to return

    Returns:
        Combined context string
    """
    try:
        print(f"[INFO] Retrieving context for query: {query[:100]}...")

        # Generate query embedding
        query_embedding = _generate_query_embedding(query)

        # Query S3 Vectors API
        print(f"[INFO] Querying S3 Vectors: bucket={VECTOR_BUCKET}, index={VECTOR_INDEX}")

        response = s3vectors_client.query_vectors(
            vectorBucketName=VECTOR_BUCKET,
            indexName=VECTOR_INDEX,
            queryVector={'float32': query_embedding},
            topK=max_results,
            returnDistance=True,
            returnMetadata=True
        )

        # Extract results (S3 Vectors returns 'vectors', not 'results'!)
        results = response.get('vectors', [])
        print(f"[INFO] Found {len(results)} matches")

        if not results:
            print("[WARNING] No matches found in S3 Vectors index")
            return ""

        # Combine context from results
        context_parts = []
        for i, result in enumerate(results):
            distance = result.get('distance', 0)
            metadata = result.get('metadata', {})

            # Extract text content from metadata
            text = metadata.get('text', '')
            source = metadata.get('source', '')

            if text:
                context_parts.append(f"[Document {i+1}] (Distance: {distance:.3f})")
                if source:
                    context_parts.append(f"Source: {source}")
                context_parts.append(text)
                context_parts.append("")  # Empty line between documents

        context = "\n".join(context_parts)
        print(f"[INFO] Retrieved {len(context)} characters of context")

        return context

    except ClientError as e:
        error_code = e.response['Error']['Code']
        print(f"[ERROR] S3 Vectors retrieval failed: {error_code} - {e}")
        # Don't fail the whole request if retrieval fails
        return ""

    except Exception as e:
        print(f"[ERROR] S3 Vectors retrieval failed: {e}")
        # Don't fail the whole request if retrieval fails
        return ""
