#!/usr/bin/env python3
"""
Example: Direct access to Secret Manager using Python client library

This demonstrates accessing secrets directly from Secret Manager without
mounting them as files. This approach is useful for:
- Local development and testing
- Dynamic secret access during runtime
- Applications that need to access many secrets
- Secret rotation without pod restarts

Usage:
  # Set up authentication
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json

  # Access secrets
  python read_secret_direct.py

  # Access specific secret
  python read_secret_direct.py --secret=my-secret-name --project=my-project

Note: This method requires the service account to have both:
  1. secretmanager.secretAccessor role on the secrets
  2. Active credentials (GOOGLE_APPLICATION_CREDENTIALS or Application Default Credentials)
"""

import argparse
import json
import sys
from typing import Optional, Dict, Any

from google.cloud import secretmanager
from google.cloud.secretmanager_v1 import AccessSecretVersionResponse
from google.api_core import exceptions


class SecretManagerClient:
    """Client for accessing Google Secret Manager."""

    def __init__(self, project_id: str):
        """
        Initialize Secret Manager client.

        Args:
            project_id: GCP project ID (not project number)
        """
        self.project_id = project_id
        self.client = secretmanager.SecretManagerServiceClient()

    def access_secret_version(
        self,
        secret_id: str,
        version: str = "latest"
    ) -> str:
        """
        Access a secret version from Secret Manager.

        Args:
            secret_id: Secret name (not full resource path)
            version: Version to access (default: "latest")

        Returns:
            Secret payload as string

        Raises:
            google.api_core.exceptions.NotFound: Secret or version not found
            google.api_core.exceptions.PermissionDenied: Lacking access permissions
        """
        # Build the resource name
        name = f"projects/{self.project_id}/secrets/{secret_id}/versions/{version}"

        try:
            # Access the secret version
            response: AccessSecretVersionResponse = self.client.access_secret_version(
                request={"name": name}
            )

            # Return the decoded payload
            payload = response.payload.data.decode("UTF-8")
            return payload

        except exceptions.NotFound:
            raise ValueError(
                f"Secret '{secret_id}' version '{version}' not found in project '{self.project_id}'\n"
                f"Verify the secret exists: gcloud secrets list --project={self.project_id}"
            )

        except exceptions.PermissionDenied:
            raise PermissionError(
                f"Permission denied accessing secret '{secret_id}'\n"
                f"Grant access with:\n"
                f"  gcloud secrets add-iam-policy-binding {secret_id} \\\n"
                f"    --project={self.project_id} \\\n"
                f"    --member='serviceAccount:YOUR_SA@{self.project_id}.iam.gserviceaccount.com' \\\n"
                f"    --role='roles/secretmanager.secretAccessor'"
            )

    def list_secrets(self) -> None:
        """List all secrets in the project."""
        parent = f"projects/{self.project_id}"

        try:
            print(f"\nSecrets in project '{self.project_id}':")
            print("─" * 60)

            for secret in self.client.list_secrets(request={"parent": parent}):
                # Extract secret name from full path
                secret_name = secret.name.split('/')[-1]
                print(f"  - {secret_name}")

                # Show labels if present
                if secret.labels:
                    labels_str = ", ".join([f"{k}={v}" for k, v in secret.labels.items()])
                    print(f"    Labels: {labels_str}")

        except exceptions.PermissionDenied:
            raise PermissionError(
                f"Permission denied listing secrets in project '{self.project_id}'\n"
                "You may have access to specific secrets but not list all secrets.\n"
                "Try accessing a specific secret by name instead."
            )

    def list_secret_versions(self, secret_id: str) -> None:
        """
        List all versions of a secret.

        Args:
            secret_id: Secret name
        """
        parent = f"projects/{self.project_id}/secrets/{secret_id}"

        try:
            print(f"\nVersions of secret '{secret_id}':")
            print("─" * 60)
            print(f"{'Version':<10} {'State':<15} {'Created':<30}")
            print("─" * 60)

            for version in self.client.list_secret_versions(request={"parent": parent}):
                version_num = version.name.split('/')[-1]
                state = version.state.name
                created = version.create_time.strftime("%Y-%m-%d %H:%M:%S UTC")

                print(f"{version_num:<10} {state:<15} {created:<30}")

        except exceptions.NotFound:
            raise ValueError(
                f"Secret '{secret_id}' not found in project '{self.project_id}'"
            )


class SecretCache:
    """Simple in-memory cache for secrets with TTL."""

    def __init__(self, ttl_seconds: int = 300):
        """
        Initialize cache.

        Args:
            ttl_seconds: Time-to-live for cached secrets (default: 5 minutes)
        """
        self.ttl_seconds = ttl_seconds
        self.cache: Dict[str, Any] = {}

    def get(self, key: str) -> Optional[str]:
        """Get secret from cache if not expired."""
        import time

        if key not in self.cache:
            return None

        cached_data = self.cache[key]
        if time.time() - cached_data['timestamp'] > self.ttl_seconds:
            # Expired
            del self.cache[key]
            return None

        return cached_data['value']

    def set(self, key: str, value: str) -> None:
        """Store secret in cache with timestamp."""
        import time

        self.cache[key] = {
            'value': value,
            'timestamp': time.time()
        }


class CachedSecretManagerClient(SecretManagerClient):
    """Secret Manager client with caching for better performance."""

    def __init__(self, project_id: str, cache_ttl: int = 300):
        """
        Initialize client with cache.

        Args:
            project_id: GCP project ID
            cache_ttl: Cache time-to-live in seconds (default: 5 minutes)
        """
        super().__init__(project_id)
        self.cache = SecretCache(cache_ttl)

    def access_secret_version(
        self,
        secret_id: str,
        version: str = "latest"
    ) -> str:
        """
        Access secret with caching.

        Note: "latest" version should have shorter TTL than pinned versions.
        """
        cache_key = f"{secret_id}:{version}"

        # Try cache first
        cached_value = self.cache.get(cache_key)
        if cached_value:
            print(f"  [Cache hit: {cache_key}]")
            return cached_value

        # Cache miss - fetch from Secret Manager
        value = super().access_secret_version(secret_id, version)

        # Store in cache
        self.cache.set(cache_key, value)

        return value


def parse_json_secret(secret_payload: str) -> Dict[str, Any]:
    """
    Parse secret payload as JSON.

    Args:
        secret_payload: Secret content as string

    Returns:
        Parsed JSON as dictionary

    Raises:
        json.JSONDecodeError: If payload is not valid JSON
    """
    try:
        return json.loads(secret_payload)
    except json.JSONDecodeError as e:
        raise ValueError(f"Secret is not valid JSON: {e}")


def example_service_account_key(client: SecretManagerClient) -> None:
    """Example: Access service account key from Secret Manager."""
    print("\n" + "─" * 60)
    print("Example 1: Service Account Key")
    print("─" * 60)

    try:
        secret_payload = client.access_secret_version("demo-app-sa-key")
        key_data = parse_json_secret(secret_payload)

        print(f"✓ Service account key retrieved")
        print(f"  Email: {key_data.get('client_email')}")
        print(f"  Project: {key_data.get('project_id')}")
        print(f"  Key ID: {key_data.get('private_key_id')}")

        # In real application, you would use this key to initialize a client
        # from google.oauth2 import service_account
        # credentials = service_account.Credentials.from_service_account_info(key_data)
        # client = storage.Client(credentials=credentials)

    except Exception as e:
        print(f"✗ Error: {e}")


def example_api_key(client: SecretManagerClient) -> None:
    """Example: Access API key from Secret Manager."""
    print("\n" + "─" * 60)
    print("Example 2: API Key")
    print("─" * 60)

    try:
        api_key = client.access_secret_version("demo-app-api-key")

        print(f"✓ API key retrieved")
        print(f"  Length: {len(api_key)} characters")
        print(f"  Preview: {api_key[:8]}...")

        # Use API key with external service
        # import requests
        # headers = {'Authorization': f'Bearer {api_key}'}
        # response = requests.get('https://api.example.com/data', headers=headers)

    except Exception as e:
        print(f"✗ Error: {e}")


def example_database_url(client: SecretManagerClient) -> None:
    """Example: Access database connection string."""
    print("\n" + "─" * 60)
    print("Example 3: Database Connection String")
    print("─" * 60)

    try:
        db_url = client.access_secret_version("demo-app-db-url")

        # Parse URL to extract info (don't print password!)
        if '://' in db_url:
            protocol = db_url.split('://')[0]
            print(f"✓ Database URL retrieved")
            print(f"  Protocol: {protocol}")

            if '@' in db_url:
                host_part = db_url.split('@')[1].split('/')[0]
                database = db_url.split('/')[-1]
                print(f"  Host: {host_part}")
                print(f"  Database: {database}")

        # Use with database library
        # import psycopg2
        # conn = psycopg2.connect(db_url)

    except Exception as e:
        print(f"✗ Error: {e}")


def example_specific_version(client: SecretManagerClient) -> None:
    """Example: Access specific version of secret."""
    print("\n" + "─" * 60)
    print("Example 4: Specific Version Access")
    print("─" * 60)

    try:
        # List versions first
        client.list_secret_versions("demo-app-api-key")

        # Access specific version
        print("\nAccessing version 1...")
        api_key_v1 = client.access_secret_version("demo-app-api-key", version="1")
        print(f"✓ Version 1 retrieved: {api_key_v1[:8]}...")

        # Access latest
        print("\nAccessing latest version...")
        api_key_latest = client.access_secret_version("demo-app-api-key", version="latest")
        print(f"✓ Latest version retrieved: {api_key_latest[:8]}...")

        # Compare
        if api_key_v1 == api_key_latest:
            print("  ℹ Version 1 is the latest version")
        else:
            print("  ℹ Version 1 differs from latest version")

    except Exception as e:
        print(f"✗ Error: {e}")


def example_caching(project_id: str) -> None:
    """Example: Using cached client for better performance."""
    print("\n" + "─" * 60)
    print("Example 5: Caching for Performance")
    print("─" * 60)

    try:
        client = CachedSecretManagerClient(project_id, cache_ttl=60)

        print("First access (cache miss):")
        secret1 = client.access_secret_version("demo-app-api-key")
        print(f"  Retrieved: {secret1[:8]}...")

        print("\nSecond access (cache hit):")
        secret2 = client.access_secret_version("demo-app-api-key")
        print(f"  Retrieved: {secret2[:8]}...")

        print("\n✓ Caching improves performance for frequently accessed secrets")
        print("  ℹ Cache TTL: 60 seconds")

    except Exception as e:
        print(f"✗ Error: {e}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Access secrets from Google Secret Manager"
    )
    parser.add_argument(
        "--project",
        default="my-project-dev",
        help="GCP project ID (default: my-project-dev)"
    )
    parser.add_argument(
        "--secret",
        help="Specific secret to access"
    )
    parser.add_argument(
        "--version",
        default="latest",
        help="Secret version to access (default: latest)"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List all secrets in project"
    )
    parser.add_argument(
        "--list-versions",
        help="List versions of a specific secret"
    )

    args = parser.parse_args()

    print("=" * 60)
    print("Secret Manager Direct Access Example")
    print("=" * 60)
    print(f"Project: {args.project}")

    try:
        client = SecretManagerClient(args.project)

        if args.list:
            client.list_secrets()
            return

        if args.list_versions:
            client.list_secret_versions(args.list_versions)
            return

        if args.secret:
            # Access specific secret
            print(f"\nAccessing secret '{args.secret}' version '{args.version}'...")
            payload = client.access_secret_version(args.secret, args.version)

            # Try to parse as JSON
            try:
                data = parse_json_secret(payload)
                print("\n✓ Secret retrieved (JSON):")
                print(json.dumps(data, indent=2))
            except ValueError:
                print("\n✓ Secret retrieved (text):")
                print(payload)

        else:
            # Run all examples
            example_service_account_key(client)
            example_api_key(client)
            example_database_url(client)
            example_specific_version(client)
            example_caching(args.project)

        print("\n" + "=" * 60)
        print("Examples complete!")
        print("=" * 60)

    except Exception as e:
        print(f"\n✗ Fatal error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(0)
