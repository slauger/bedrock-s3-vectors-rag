"""
Build S3 Vectors index from local Git repository content
Much simpler than FAISS - no ML dependencies, uses Bedrock Titan for embeddings
"""

import os
import json
from pathlib import Path
from typing import List, Dict
import boto3
from botocore.exceptions import ClientError

# Configuration
# Use knowledge-base/ directory (output from extract-kb-content.py)
CONTENT_DIR = os.environ.get('CONTENT_DIR', None)
if CONTENT_DIR:
    CONTENT_DIR = Path(CONTENT_DIR)
else:
    # Auto-detect: knowledge-base directory in repo root
    kb_path = Path(__file__).parent.parent.parent.parent / 'knowledge-base'
    CONTENT_DIR = kb_path

VECTOR_BUCKET = os.environ.get('S3_VECTORS_BUCKET', 'your-project-dev-vector-bucket')
VECTOR_INDEX = os.environ.get('S3_VECTORS_INDEX', 'kb-index')
BEDROCK_EMBED_MODEL = os.environ.get('BEDROCK_EMBED_MODEL', 'amazon.titan-embed-text-v2:0')
AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')

# AWS Clients
s3vectors_client = boto3.client('s3vectors', region_name=AWS_REGION)
bedrock_runtime = boto3.client('bedrock-runtime', region_name=AWS_REGION)


def load_markdown_files(content_dir: Path) -> List[Dict[str, str]]:
    """Load all markdown files from knowledge-base directory"""
    print(f"📂 Loading markdown files from {content_dir}")

    documents = []

    # Recursively find all .md files
    for md_file in content_dir.rglob('*.md'):
        # Skip files that start with underscore
        if md_file.name.startswith('_'):
            continue

        # Read file
        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                content = f.read()

            # Skip empty files
            if not content.strip():
                continue

            # Store relative path for debugging
            rel_path = md_file.relative_to(content_dir)

            documents.append({
                'path': str(rel_path),
                'content': content
            })
            print(f"  ✓ {rel_path} ({len(content)} chars)")

        except Exception as e:
            print(f"  ✗ Error reading {md_file}: {e}")
            continue

    print(f"✅ Loaded {len(documents)} documents")
    return documents


def chunk_documents(documents: List[Dict], chunk_size: int = 500, overlap: int = 50) -> List[Dict]:
    """Split documents into chunks for better retrieval"""
    print(f"✂️  Chunking documents (size={chunk_size}, overlap={overlap})")

    chunks = []

    for doc in documents:
        content = doc['content']

        # Simple chunking by characters
        start = 0
        chunk_idx = 0
        while start < len(content):
            end = start + chunk_size
            chunk_text = content[start:end]

            if chunk_text.strip():
                chunks.append({
                    'source': doc['path'],
                    'text': chunk_text,
                    'chunk_index': chunk_idx,
                    'start': start,
                    'end': end
                })
                chunk_idx += 1

            start += (chunk_size - overlap)

    print(f"✅ Created {len(chunks)} chunks")
    return chunks


def generate_embedding(text: str) -> List[float]:
    """Generate embedding using Bedrock Titan"""
    try:
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_EMBED_MODEL,
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                'inputText': text
            })
        )

        response_body = json.loads(response['body'].read())
        return response_body['embedding']

    except Exception as e:
        print(f"  ✗ Error generating embedding: {e}")
        raise


def create_s3_vectors_index(chunks: List[Dict]):
    """Create S3 Vectors index and upload vectors"""
    print(f"🔢 Creating S3 Vectors index: bucket={VECTOR_BUCKET}, index={VECTOR_INDEX}")

    try:
        # Check if vector bucket exists, create if not
        try:
            s3vectors_client.get_vector_bucket(vectorBucketName=VECTOR_BUCKET)
            print(f"  ✓ Vector bucket exists: {VECTOR_BUCKET}")
        except ClientError as e:
            if e.response['Error']['Code'] == 'NotFoundException':
                print(f"  Creating vector bucket: {VECTOR_BUCKET}")
                s3vectors_client.create_vector_bucket(vectorBucketName=VECTOR_BUCKET)
                print(f"  ✓ Created vector bucket")
            else:
                raise

        # Delete existing index if it exists
        try:
            s3vectors_client.delete_index(
                vectorBucketName=VECTOR_BUCKET,
                indexName=VECTOR_INDEX
            )
            print(f"  ✓ Deleted existing index")
        except ClientError as e:
            if 'NotFound' not in str(e):
                print(f"  ℹ️  No existing index to delete")

        # Create new index - first get dimension from one embedding
        print(f"🤖 Generating sample embedding to determine dimension...")
        sample_embedding = generate_embedding(chunks[0]['text'])
        dimension = len(sample_embedding)
        print(f"  ℹ️  Detected embedding dimension: {dimension}")

        # Create index
        s3vectors_client.create_index(
            vectorBucketName=VECTOR_BUCKET,
            indexName=VECTOR_INDEX,
            dimension=dimension,
            dataType='float32',  # Required: float32 or float16
            distanceMetric='cosine'  # Required: cosine, euclidean, or dotProduct
        )
        print(f"  ✓ Created S3 Vectors index")

        # Prepare all vectors for batch upload
        print(f"🤖 Generating embeddings for {len(chunks)} chunks...")
        vectors = []

        for i, chunk in enumerate(chunks):
            # Generate embedding
            embedding = generate_embedding(chunk['text'])

            vectors.append({
                'key': f"chunk_{i:05d}",
                'data': {'float32': embedding},
                'metadata': {
                    'text': chunk['text'][:1000],  # Limit metadata size
                    'source': chunk['source'],
                    'chunk_index': str(chunk['chunk_index']),
                    'start': str(chunk['start']),
                    'end': str(chunk['end'])
                }
            })

            # Progress indicator
            if (i + 1) % 10 == 0:
                print(f"  ✓ Generated {i + 1}/{len(chunks)} embeddings")

        # Upload vectors in batches (S3 Vectors API supports batch upload)
        print(f"📤 Uploading {len(vectors)} vectors...")
        BATCH_SIZE = 100

        for i in range(0, len(vectors), BATCH_SIZE):
            batch = vectors[i:i+BATCH_SIZE]
            s3vectors_client.put_vectors(
                vectorBucketName=VECTOR_BUCKET,
                indexName=VECTOR_INDEX,
                vectors=batch
            )
            print(f"  ✓ Uploaded batch {i//BATCH_SIZE + 1} ({len(batch)} vectors)")

        print(f"✅ S3 Vectors index created: {len(chunks)} vectors, dimension={dimension}")

    except Exception as e:
        print(f"❌ Failed to create S3 Vectors index: {e}")
        import traceback
        traceback.print_exc()
        raise


def main():
    """Main build process"""
    print("=" * 60)
    print("🏗️  Building S3 Vectors Index from Git Repository")
    print("=" * 60)
    print()

    # Check content directory exists
    if not CONTENT_DIR.exists():
        print(f"❌ Content directory not found: {CONTENT_DIR}")
        print(f"   Current dir: {Path.cwd()}")
        return

    # 1. Load markdown files from Git repo
    documents = load_markdown_files(CONTENT_DIR)

    if not documents:
        print("❌ No documents found!")
        return

    print()

    # 2. Chunk documents
    chunks = chunk_documents(documents, chunk_size=500, overlap=50)
    print()

    # 3. Create S3 Vectors index
    create_s3_vectors_index(chunks)
    print()

    print("=" * 60)
    print("✅ S3 Vectors Index Build Complete!")
    print("=" * 60)


if __name__ == '__main__':
    main()
