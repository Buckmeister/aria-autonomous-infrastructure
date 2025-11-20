#!/usr/bin/env python3
"""
Matrix Client Library for Aria Autonomous Infrastructure

Python equivalent of the bash Matrix libraries, providing clean API
for Matrix integration in Python scripts.

Usage:
    from matrix_client import MatrixClient

    # Initialize client
    client = MatrixClient()  # Uses default config path

    # Send message
    event_id = client.send_message("Hello from Python!")

    # Send formatted event
    client.send_event("Notification", "Task completed")

    # Check connection
    if client.check_connection():
        print("Matrix server reachable")

Features:
- Automatic configuration loading
- Event message formatting
- Error handling and retries
- Consistent with bash libraries
"""

import json
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime


class MatrixClient:
    """Matrix client for autonomous AI instances"""

    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize Matrix client with configuration

        Args:
            config_path: Path to matrix-credentials.json (optional)
                        Defaults to ~/aria-workspace/aria-autonomous-infrastructure/config/matrix-credentials.json
        """
        if config_path is None:
            config_path = (
                Path.home()
                / "aria-workspace"
                / "aria-autonomous-infrastructure"
                / "config"
                / "matrix-credentials.json"
            )

        self.config_path = config_path
        self.config = self._load_config()

        # Extract configuration
        self.homeserver = self.config["homeserver"]
        self.access_token = self.config["access_token"]
        self.room_id = self.config["room_id"]
        self.user_id = self.config.get("user_id", "")
        self.instance_name = self.config.get("instance_name", "AI Instance")

    def _load_config(self) -> Dict[str, Any]:
        """
        Load configuration from JSON file

        Returns:
            Dictionary with configuration

        Raises:
            FileNotFoundError: If config file doesn't exist
            json.JSONDecodeError: If config file is invalid JSON
        """
        if not self.config_path.exists():
            raise FileNotFoundError(
                f"Matrix config file not found: {self.config_path}\n"
                f"Please create config/matrix-credentials.json from the example"
            )

        with open(self.config_path) as f:
            return json.load(f)

    def send_message(self, message: str) -> Optional[str]:
        """
        Send text message to Matrix room

        Args:
            message: Message body to send

        Returns:
            Event ID if successful, None on error
        """
        if not message:
            print("Error: Message body required", file=sys.stderr)
            return None

        # Build JSON payload
        payload = {"msgtype": "m.text", "body": message}

        # Send via Matrix API using curl
        cmd = [
            "curl",
            "-s",
            "-X",
            "POST",
            "-H",
            f"Authorization: Bearer {self.access_token}",
            "-H",
            "Content-Type: application/json",
            "-d",
            json.dumps(payload),
            f"{self.homeserver}/_matrix/client/r0/rooms/{self.room_id}/send/m.room.message",
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            response = json.loads(result.stdout)

            # Extract event_id
            event_id = response.get("event_id")

            if event_id:
                return event_id
            else:
                # Check for error
                error_code = response.get("errcode")
                if error_code:
                    error_msg = response.get("error", "Unknown error")
                    print(
                        f"Matrix API error: {error_code} - {error_msg}",
                        file=sys.stderr,
                    )
                else:
                    print(f"Failed to send message: {response}", file=sys.stderr)
                return None

        except subprocess.TimeoutExpired:
            print("Matrix API request timed out", file=sys.stderr)
            return None
        except json.JSONDecodeError as e:
            print(f"Failed to parse Matrix API response: {e}", file=sys.stderr)
            return None
        except Exception as e:
            print(f"Error sending Matrix message: {e}", file=sys.stderr)
            return None

    def format_event_message(self, event_type: str, message: str = "") -> str:
        """
        Format event message with emoji and instance name

        Args:
            event_type: Type of event (SessionStart, Notification, Error, etc.)
            message: Optional message text

        Returns:
            Formatted message string
        """
        emoji_map = {
            "SessionStart": "🚀",
            "SessionEnd": "👋",
            "Stop": "✅",
            "SubagentStop": "🤖",
            "Notification": "📢",
            "Error": "❌",
            "Info": "ℹ️",
            "Success": "✅",
            "Warning": "⚠️",
            "Research": "🔬",
            "Interview": "💭",
            "Debug": "🐛",
        }

        emoji = emoji_map.get(event_type, "ℹ️")

        # Build message based on event type
        if event_type == "SessionStart":
            msg = f"[{self.instance_name}] Session started"
        elif event_type == "SessionEnd":
            msg = f"[{self.instance_name}] Session ended"
        elif event_type == "Stop":
            msg = f"[{self.instance_name}] Task completed"
            if message:
                msg += f": {message}"
        elif event_type == "SubagentStop":
            msg = f"[{self.instance_name}] Agent task completed"
            if message:
                msg += f": {message}"
        elif event_type in ["Notification", "Info", "Success", "Research", "Interview"]:
            msg = f"[{self.instance_name}] {message}"
        elif event_type in ["Error", "Warning", "Debug"]:
            msg = f"[{self.instance_name}] {event_type}: {message}"
        else:
            msg = f"[{self.instance_name}] {event_type}: {message}"

        return f"{emoji} {msg}"

    def send_event(self, event_type: str, message: str = "") -> Optional[str]:
        """
        Send formatted event notification to Matrix

        Args:
            event_type: Type of event
            message: Optional message text

        Returns:
            Event ID if successful, None on error
        """
        formatted_message = self.format_event_message(event_type, message)
        return self.send_message(formatted_message)

    def check_connection(self) -> bool:
        """
        Check if Matrix server is reachable

        Returns:
            True if server reachable, False otherwise
        """
        cmd = [
            "curl",
            "-s",
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            f"{self.homeserver}/_matrix/client/versions",
        ]

        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=5
            )
            http_code = result.stdout.strip()
            return http_code == "200"
        except Exception:
            return False

    def get_instance_name(self) -> str:
        """Get configured instance name"""
        return self.instance_name

    def get_instance_id(self) -> str:
        """Get instance identifier (lowercase, hyphenated)"""
        return self.instance_name.lower().replace(" ", "-")

    def generate_session_id(self) -> str:
        """
        Generate unique session ID

        Returns:
            Session ID string (e.g., "aria-nova-20251120-143000-12345")
        """
        import os

        instance_id = self.get_instance_id()
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        pid = os.getpid()

        return f"{instance_id}-{timestamp}-{pid}"


# Convenience function for quick usage
def send_notification(event_type: str, message: str = "") -> bool:
    """
    Convenience function to send notification without creating client instance

    Args:
        event_type: Event type
        message: Optional message

    Returns:
        True if successful, False otherwise
    """
    try:
        client = MatrixClient()
        event_id = client.send_event(event_type, message)
        return event_id is not None
    except Exception as e:
        print(f"Failed to send notification: {e}", file=sys.stderr)
        return False


if __name__ == "__main__":
    """Test the Matrix client"""
    import sys

    print("Testing Matrix Client Library")
    print("=" * 50)

    try:
        client = MatrixClient()
        print(f"✓ Config loaded")
        print(f"  Instance: {client.instance_name}")
        print(f"  Server: {client.homeserver}")
        print(f"  Room: {client.room_id}")
        print()

        # Test connection
        print("Testing connection...")
        if client.check_connection():
            print("✓ Server reachable")
        else:
            print("✗ Server unreachable")
            sys.exit(1)

        print()

        # Test sending message
        print("Sending test message...")
        event_id = client.send_event("Info", "Matrix client library test")

        if event_id:
            print(f"✓ Message sent: {event_id}")
        else:
            print("✗ Failed to send message")
            sys.exit(1)

        print()
        print("All tests passed! ✅")

    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(1)
