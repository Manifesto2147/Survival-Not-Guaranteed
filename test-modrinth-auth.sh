#!/bin/bash

# Test Modrinth authentication
# Usage: ./test-modrinth-auth.sh "your-token-here" "your-project-id-here"

TOKEN="$1"
PROJECT_ID="$2"

if [ -z "$TOKEN" ] || [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <modrinth-token> <project-id>"
    echo "Example: $0 'mrp_your_token_here' 'your-project-id'"
    exit 1
fi

echo "🔐 Testing Modrinth authentication..."
echo "Token: ${TOKEN:0:10}..."
echo "Project ID: $PROJECT_ID"
echo

# Test authentication
echo "📡 Testing API authentication..."
AUTH_RESPONSE=$(curl -s -H "Authorization: $TOKEN" \
    "https://api.modrinth.com/v2/user" 2>/dev/null)

if echo "$AUTH_RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
    USERNAME=$(echo "$AUTH_RESPONSE" | jq -r '.username')
    echo "✅ Authentication successful! Logged in as: $USERNAME"
else
    echo "❌ Authentication failed!"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

# Test project access
echo "📦 Testing project access..."
PROJECT_RESPONSE=$(curl -s -H "Authorization: $TOKEN" \
    "https://api.modrinth.com/v2/project/$PROJECT_ID" 2>/dev/null)

if echo "$PROJECT_RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
    PROJECT_NAME=$(echo "$PROJECT_RESPONSE" | jq -r '.title')
    echo "✅ Project access successful! Project: $PROJECT_NAME"
else
    echo "❌ Project access failed!"
    echo "Response: $PROJECT_RESPONSE"
    exit 1
fi

echo
echo "🎉 All tests passed! Your credentials are configured correctly."
echo "You can now add these to GitHub secrets:"
echo "- MODRINTH_TOKEN: $TOKEN"
echo "- MODRINTH_PROJECT_ID: $PROJECT_ID"
