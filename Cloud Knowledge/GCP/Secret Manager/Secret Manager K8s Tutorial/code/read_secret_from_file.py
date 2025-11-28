#!/usr/bin/env python3
"""
Example: Reading secrets from files mounted by CSI driver

This demonstrates the most common pattern for accessing secrets in GKE pods.
The Secrets Store CSI driver mounts secrets as files, and the application
reads them at runtime.

Usage in GKE pod:
  - Secrets are mounted at /var/secrets/ by CSI driver
  - GOOGLE_APPLICATION_CREDENTIALS points to service account key
  - Application reads credentials and initializes clients

Local testing:
  export GOOGLE_APPLICATION_CREDENTIALS=/tmp/credentials.json
  python read_secret_from_file.py
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Any

from google.cloud import storage
from google.cloud import secretmanager


class SecretFileReader:
    """Helper class for reading secrets from mounted files."""

    def __init__(self, secrets_dir: str = "/var/secrets"):
        """
        Initialize secret reader.

        Args:
            secrets_dir: Directory where secrets are mounted (default: /var/secrets)
        """
        self.secrets_dir = Path(secrets_dir)

    def read_json_secret(self, filename: str) -> Dict[str, Any]:
        """
        Read and parse JSON secret file.

        Args:
            filename: Name of secret file (e.g., 'credentials.json')

        Returns:
            Parsed JSON as dictionary

        Raises:
            FileNotFoundError: If secret file doesn't exist
            json.JSONDecodeError: If file is not valid JSON
        """
        secret_path = self.secrets_dir / filename

        if not secret_path.exists():
            raise FileNotFoundError(
                f"Secret file not found: {secret_path}\n"
                f"Verify SecretProviderClass is configured correctly and pod has mounted the volume."
            )

        with open(secret_path, 'r') as f:
            try:
                return json.load(f)
            except json.JSONDecodeError as e:
                raise json.JSONDecodeError(
                    f"Invalid JSON in secret file {secret_path}: {e.msg}",
                    e.doc,
                    e.pos
                )

    def read_text_secret(self, filename: str) -> str:
        """
        Read text secret file.

        Args:
            filename: Name of secret file (e.g., 'api-key.txt')

        Returns:
            Secret content as string (stripped of whitespace)

        Raises:
            FileNotFoundError: If secret file doesn't exist
        """
        secret_path = self.secrets_dir / filename

        if not secret_path.exists():
            raise FileNotFoundError(
                f"Secret file not found: {secret_path}\n"
                f"Verify SecretProviderClass is configured correctly."
            )

        with open(secret_path, 'r') as f:
            return f.read().strip()

    def validate_service_account_key(self, key_data: Dict[str, Any]) -> None:
        """
        Validate that service account key has required fields.

        Args:
            key_data: Parsed service account key JSON

        Raises:
            ValueError: If required fields are missing
        """
        required_fields = [
            'type',
            'project_id',
            'private_key_id',
            'private_key',
            'client_email',
            'client_id',
        ]

        missing_fields = [field for field in required_fields if field not in key_data]

        if missing_fields:
            raise ValueError(
                f"Invalid service account key: missing fields {missing_fields}"
            )

        if key_data['type'] != 'service_account':
            raise ValueError(
                f"Invalid key type: expected 'service_account', got '{key_data['type']}'"
            )


class StorageClientExample:
    """Example application using Cloud Storage with mounted credentials."""

    def __init__(self, secrets_dir: str = "/var/secrets"):
        """
        Initialize storage client.

        Args:
            secrets_dir: Directory where secrets are mounted
        """
        self.secret_reader = SecretFileReader(secrets_dir)
        self.storage_client = None

    def initialize_client(self) -> storage.Client:
        """
        Initialize Cloud Storage client using mounted service account key.

        The Google Cloud client libraries automatically detect credentials from
        GOOGLE_APPLICATION_CREDENTIALS environment variable.

        Returns:
            Initialized storage.Client

        Raises:
            FileNotFoundError: If credentials file not found
            ValueError: If credentials are invalid
        """
        # Get credentials path from environment variable
        credentials_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')

        if not credentials_path:
            raise ValueError(
                "GOOGLE_APPLICATION_CREDENTIALS environment variable not set.\n"
                "In Kubernetes deployment, set this to point to mounted secret file."
            )

        # Validate file exists
        if not os.path.exists(credentials_path):
            raise FileNotFoundError(
                f"Credentials file not found: {credentials_path}\n"
                "Verify the CSI driver volume is mounted correctly."
            )

        # Load and validate key structure
        with open(credentials_path, 'r') as f:
            key_data = json.load(f)

        self.secret_reader.validate_service_account_key(key_data)

        print(f"✓ Credentials loaded from: {credentials_path}")
        print(f"✓ Service Account: {key_data['client_email']}")
        print(f"✓ Project: {key_data['project_id']}")

        # Initialize client (automatically uses GOOGLE_APPLICATION_CREDENTIALS)
        self.storage_client = storage.Client()

        return self.storage_client

    def upload_file(
        self,
        bucket_name: str,
        source_file: str,
        destination_blob: str
    ) -> None:
        """
        Upload file to Cloud Storage.

        Args:
            bucket_name: Name of GCS bucket
            source_file: Local file path to upload
            destination_blob: Destination path in bucket

        Raises:
            google.cloud.exceptions.NotFound: If bucket doesn't exist
            google.cloud.exceptions.Forbidden: If lacking permissions
        """
        if not self.storage_client:
            self.initialize_client()

        bucket = self.storage_client.bucket(bucket_name)
        blob = bucket.blob(destination_blob)

        print(f"Uploading {source_file} to gs://{bucket_name}/{destination_blob}...")
        blob.upload_from_filename(source_file)
        print(f"✓ Upload complete")

    def list_buckets(self) -> None:
        """List all buckets in the project."""
        if not self.storage_client:
            self.initialize_client()

        print("\nBuckets in project:")
        for bucket in self.storage_client.list_buckets():
            print(f"  - {bucket.name}")


class APIKeyExample:
    """Example application using API key from mounted secret."""

    def __init__(self, secrets_dir: str = "/var/secrets"):
        """Initialize with secrets directory."""
        self.secret_reader = SecretFileReader(secrets_dir)

    def load_api_key(self, filename: str = "api-key.txt") -> str:
        """
        Load API key from mounted secret file.

        Args:
            filename: Name of secret file containing API key

        Returns:
            API key string
        """
        api_key = self.secret_reader.read_text_secret(filename)

        if not api_key:
            raise ValueError(f"API key file {filename} is empty")

        print(f"✓ API key loaded from {filename}")
        print(f"  Key length: {len(api_key)} characters")
        print(f"  Key preview: {api_key[:8]}...")

        return api_key

    def use_api_key(self, api_key: str) -> None:
        """
        Example of using API key with external service.

        Args:
            api_key: API key to use
        """
        # In real application, you would use the API key with requests
        # Example:
        # import requests
        # headers = {'Authorization': f'Bearer {api_key}'}
        # response = requests.get('https://api.example.com/data', headers=headers)

        print(f"\n✓ Using API key for authentication")
        print(f"  (In real app, this would call external API)")


class DatabaseConnectionExample:
    """Example application using database connection string."""

    def __init__(self, secrets_dir: str = "/var/secrets"):
        """Initialize with secrets directory."""
        self.secret_reader = SecretFileReader(secrets_dir)

    def load_database_url(self, filename: str = "database-url.txt") -> str:
        """
        Load database connection string.

        Args:
            filename: Name of secret file containing database URL

        Returns:
            Database connection string
        """
        db_url = self.secret_reader.read_text_secret(filename)

        if not db_url:
            raise ValueError(f"Database URL file {filename} is empty")

        # Parse URL to verify format (don't print password!)
        if '://' in db_url:
            protocol = db_url.split('://')[0]
            print(f"✓ Database URL loaded from {filename}")
            print(f"  Protocol: {protocol}")

            # Extract host without exposing password
            if '@' in db_url:
                host_part = db_url.split('@')[1].split('/')[0]
                print(f"  Host: {host_part}")
        else:
            raise ValueError(f"Invalid database URL format in {filename}")

        return db_url


def main():
    """Main application entry point."""
    print("=" * 60)
    print("Secret Manager CSI Driver - File-based Secret Access Example")
    print("=" * 60)

    # Determine secrets directory (local vs GKE)
    if os.path.exists("/var/secrets"):
        secrets_dir = "/var/secrets"
        print("\n✓ Running in GKE pod (using /var/secrets)")
    else:
        secrets_dir = "/tmp/demo-app-secrets"
        print(f"\n✓ Running locally (using {secrets_dir})")
        print("  To test: Run scripts/03-local-access.sh first")

    print()

    # Example 1: Service Account Key and Cloud Storage
    print("\n" + "─" * 60)
    print("Example 1: Cloud Storage Access with Service Account Key")
    print("─" * 60)

    try:
        storage_example = StorageClientExample(secrets_dir)
        storage_example.initialize_client()
        # Uncomment to list buckets (requires Storage Viewer permission)
        # storage_example.list_buckets()
    except Exception as e:
        print(f"✗ Error: {e}")

    # Example 2: API Key
    print("\n" + "─" * 60)
    print("Example 2: API Key Access")
    print("─" * 60)

    try:
        api_example = APIKeyExample(secrets_dir)
        api_key = api_example.load_api_key()
        api_example.use_api_key(api_key)
    except Exception as e:
        print(f"✗ Error: {e}")

    # Example 3: Database Connection
    print("\n" + "─" * 60)
    print("Example 3: Database Connection String")
    print("─" * 60)

    try:
        db_example = DatabaseConnectionExample(secrets_dir)
        db_url = db_example.load_database_url()
        print(f"✓ Database connection string loaded successfully")
    except Exception as e:
        print(f"✗ Error: {e}")

    print("\n" + "=" * 60)
    print("All examples complete!")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n✗ Fatal error: {e}", file=sys.stderr)
        sys.exit(1)
