#!/usr/bin/env python3
"""
Upload files to Google Cloud Storage using Service Account credentials.

This example demonstrates how to use a Service Account with Storage Object Creator
role to upload files to a GCS bucket.

Prerequisites:
    pip install google-cloud-storage

Usage:
    # Set credentials (for local development)
    export GOOGLE_APPLICATION_CREDENTIALS=~/demo-uploader-key.json

    # Run the script
    python upload_to_gcs.py

    # Or specify custom bucket and file
    python upload_to_gcs.py --bucket my-bucket --file myfile.txt
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from google.cloud import storage
from google.api_core import exceptions
import argparse


def upload_file_to_gcs(
    bucket_name: str,
    source_file_path: str,
    destination_blob_name: str = None
) -> bool:
    """
    Uploads a file to Google Cloud Storage.

    Args:
        bucket_name: Name of the GCS bucket
        source_file_path: Path to the local file to upload
        destination_blob_name: Name for the file in GCS (optional, defaults to filename)

    Returns:
        True if upload succeeded, False otherwise
    """
    try:
        # Initialize the Cloud Storage client
        # This automatically uses credentials from GOOGLE_APPLICATION_CREDENTIALS
        # environment variable or Application Default Credentials
        storage_client = storage.Client()

        # Get the bucket
        bucket = storage_client.bucket(bucket_name)

        # If no destination name provided, use the source filename
        if destination_blob_name is None:
            destination_blob_name = Path(source_file_path).name

        # Create a blob (object) in the bucket
        blob = bucket.blob(destination_blob_name)

        # Upload the file
        print(f"Uploading {source_file_path} to gs://{bucket_name}/{destination_blob_name}...")

        blob.upload_from_filename(source_file_path)

        print(f"✓ File uploaded successfully!")
        print(f"  GCS URI: gs://{bucket_name}/{destination_blob_name}")
        print(f"  Size: {blob.size} bytes")
        print(f"  Content Type: {blob.content_type}")

        return True

    except exceptions.Forbidden as e:
        print(f"✗ Permission denied: {e}", file=sys.stderr)
        print("\nPossible causes:", file=sys.stderr)
        print("  • Service Account doesn't have objectCreator role on this bucket", file=sys.stderr)
        print("  • GOOGLE_APPLICATION_CREDENTIALS not set correctly", file=sys.stderr)
        print("  • Bucket doesn't exist", file=sys.stderr)
        return False

    except exceptions.NotFound as e:
        print(f"✗ Bucket not found: {e}", file=sys.stderr)
        print(f"\nMake sure bucket '{bucket_name}' exists", file=sys.stderr)
        return False

    except FileNotFoundError:
        print(f"✗ File not found: {source_file_path}", file=sys.stderr)
        return False

    except Exception as e:
        print(f"✗ Unexpected error: {e}", file=sys.stderr)
        return False


def upload_string_to_gcs(
    bucket_name: str,
    content: str,
    destination_blob_name: str,
    content_type: str = "text/plain"
) -> bool:
    """
    Uploads string content directly to GCS without creating a local file.

    Args:
        bucket_name: Name of the GCS bucket
        content: String content to upload
        destination_blob_name: Name for the file in GCS
        content_type: MIME type of the content

    Returns:
        True if upload succeeded, False otherwise
    """
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)

        print(f"Uploading content to gs://{bucket_name}/{destination_blob_name}...")

        blob.upload_from_string(content, content_type=content_type)

        print(f"✓ Content uploaded successfully!")
        print(f"  GCS URI: gs://{bucket_name}/{destination_blob_name}")
        print(f"  Size: {blob.size} bytes")

        return True

    except Exception as e:
        print(f"✗ Error uploading content: {e}", file=sys.stderr)
        return False


def create_test_file(filename: str = "test-upload.txt") -> str:
    """
    Creates a simple test file for uploading.

    Args:
        filename: Name of the test file to create

    Returns:
        Path to the created file
    """
    content = f"""Test File for GCS Upload
========================

This file was created at: {datetime.now().isoformat()}

This demonstrates uploading a file to Google Cloud Storage
using a Service Account with Storage Object Creator role.

The Service Account can:
  ✓ Upload this file
  ✗ Read this file back (no read permission)
  ✗ Delete this file (no delete permission)

This follows the Principle of Least Privilege!
"""

    with open(filename, "w") as f:
        f.write(content)

    print(f"Created test file: {filename}")
    return filename


def verify_credentials():
    """
    Verifies that credentials are properly configured.

    Returns:
        True if credentials are valid, False otherwise
    """
    creds_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")

    if not creds_path:
        print("⚠ Warning: GOOGLE_APPLICATION_CREDENTIALS not set", file=sys.stderr)
        print("Will attempt to use Application Default Credentials", file=sys.stderr)
        print("\nTo set credentials:", file=sys.stderr)
        print("  export GOOGLE_APPLICATION_CREDENTIALS=~/demo-uploader-key.json", file=sys.stderr)
        return True

    if not Path(creds_path).exists():
        print(f"✗ Credentials file not found: {creds_path}", file=sys.stderr)
        return False

    print(f"✓ Using credentials: {creds_path}")

    try:
        storage_client = storage.Client()
        # Try to get the service account email
        print(f"✓ Authenticated as: {storage_client.get_service_account_email()}")
        return True
    except Exception as e:
        print(f"✗ Error validating credentials: {e}", file=sys.stderr)
        return False


def main():
    """Main function to demonstrate uploading files to GCS."""
    parser = argparse.ArgumentParser(
        description="Upload files to Google Cloud Storage using Service Account"
    )
    parser.add_argument(
        "--bucket",
        help="GCS bucket name (without gs:// prefix)",
        default=None
    )
    parser.add_argument(
        "--file",
        help="Local file to upload",
        default=None
    )
    parser.add_argument(
        "--destination",
        help="Destination path in GCS (optional)",
        default=None
    )
    parser.add_argument(
        "--create-test-file",
        action="store_true",
        help="Create a test file and upload it"
    )

    args = parser.parse_args()

    print("=" * 60)
    print("  Google Cloud Storage Upload Demo")
    print("=" * 60)
    print()

    # Verify credentials
    if not verify_credentials():
        return 1

    print()

    # Get bucket name
    bucket_name = args.bucket
    if not bucket_name:
        # Try to get from temp file created by the setup script
        temp_file = Path("/tmp/demo-bucket-name.txt")
        if temp_file.exists():
            bucket_name = temp_file.read_text().strip()
            print(f"Using bucket from setup: {bucket_name}")
        else:
            print("Error: No bucket specified", file=sys.stderr)
            print("\nUsage:", file=sys.stderr)
            print("  python upload_to_gcs.py --bucket demo-upload-bucket-YOUR_PROJECT", file=sys.stderr)
            print("\nOr run the setup script first:", file=sys.stderr)
            print("  cd ../scripts && ./02-grant-bucket-access.sh", file=sys.stderr)
            return 1

    print()

    # Determine what to upload
    if args.create_test_file or not args.file:
        # Create and upload a test file
        test_file = create_test_file()
        print()

        success = upload_file_to_gcs(
            bucket_name=bucket_name,
            source_file_path=test_file,
            destination_blob_name=args.destination or f"test-uploads/{test_file}"
        )

        # Also upload some string content
        if success:
            print()
            print("-" * 60)
            print()
            timestamp = datetime.now().isoformat()
            content = f"Test upload at {timestamp}\nGenerated by upload_to_gcs.py"

            upload_string_to_gcs(
                bucket_name=bucket_name,
                content=content,
                destination_blob_name=f"test-uploads/timestamp-{timestamp}.txt"
            )

    else:
        # Upload specified file
        success = upload_file_to_gcs(
            bucket_name=bucket_name,
            source_file_path=args.file,
            destination_blob_name=args.destination
        )

    print()
    print("=" * 60)

    if success:
        print("✓ Upload completed successfully!")
        print()
        print("Note: With Storage Object Creator role, you can:")
        print("  • Upload new files ✓")
        print("  • List files (basic) ✓")
        print("  • Read/download files ✗")
        print("  • Delete files ✗")
        print()
        print("To view uploaded files in Cloud Console:")
        print(f"  https://console.cloud.google.com/storage/browser/{bucket_name}")
    else:
        print("✗ Upload failed")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
