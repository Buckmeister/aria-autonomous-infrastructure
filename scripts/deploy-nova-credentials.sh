#!/bin/bash
# Deploy Fresh Aria Nova Credentials to lat-bck00
# Generated: 2025-10-27

set -e

echo "🔐 Deploying fresh Aria Nova credentials to lat-bck00..."

# Fresh credentials from Matrix login (2025-10-27)
ssh -i ~/.aria/ssh/aria_key aria@lat-bck00 'cd ~/aria-workspace/aria-autonomous-infrastructure && cat > config/matrix-credentials.json << EOF
{
  "homeserver": "http://srv1.bck.intern:8008",
  "user_id": "@arianova:srv1.local",
  "access_token": "syt_YXJpYW5vdmE_KWRYvzLQhjhZqwFSOoCu_4D08Qa",
  "device_id": "TWLRCEAOMT",
  "room_id": "!UCEurIvKNNMvYlrntC:srv1.local",
  "instance_name": "Aria Nova"
}
EOF
echo "✅ Credentials deployed"
cat config/matrix-credentials.json'

echo ""
echo "✅ Credentials deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Validate credentials with API test"
echo "2. Restart event handler daemon"
echo "3. Test with message to trigger autonomous session"
