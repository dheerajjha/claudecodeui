#!/bin/bash

# Start Claude Code UI with Internet Access
# This script starts the local server and creates a Cloudflare tunnel for internet access

echo "🚀 Starting Claude Code UI with Internet Access"
echo "================================================================"

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared is not installed."
    echo "   Install it with:"
    echo "   macOS: brew install cloudflare/cloudflare/cloudflared"
    echo "   Linux: Follow instructions at https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
    exit 1
fi

# Check cloudflared authentication
echo "🔍 Checking Cloudflare Tunnel setup..."
if ! cloudflared tunnel list &> /dev/null; then
    echo "⚠️  Cloudflare Tunnel authentication not configured"
    echo "   To set up Cloudflare Tunnel:"
    echo "   1. Login: cloudflared tunnel login"
    echo "   2. Create tunnel: cloudflared tunnel create claude-code-ui"
    echo "   3. Configure DNS: cloudflared tunnel route dns claude-code-ui your-domain.com"
    echo ""
    echo "   For quick setup without custom domain, we'll use a temporary tunnel..."
    USE_TEMP_TUNNEL=true
else
    echo "✅ Cloudflare Tunnel is configured"
    USE_TEMP_TUNNEL=false
fi

# Check if the application is already running
if pgrep -f "node server/index.js" > /dev/null; then
    echo "⚠️  Application is already running. Stopping existing instance..."
    pkill -f "node server/index.js"
    sleep 2
fi

# Check for existing cloudflared processes
if pgrep -f "cloudflared tunnel" > /dev/null; then
    echo "⚠️  Existing Cloudflare tunnel found. Stopping it..."
    pkill -f "cloudflared tunnel"
    sleep 2
fi

echo "📦 Building the application..."
npm run build

echo "🌐 Starting local server..."
npm run server > /tmp/claude-server.log 2>&1 &
SERVER_PID=$!

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 5

# Extract the actual port from server output
SERVER_PORT=$(grep -o "running on.*:[0-9]*" /tmp/claude-server.log | grep -o "[0-9]*" | tail -1)
if [ -z "$SERVER_PORT" ]; then
  echo "⚠️  Could not detect server port from logs, checking environment..."
  SERVER_PORT=${PORT:-3000}  # Use PORT env var or default to 3000
fi

# Check if server started successfully
if ! pgrep -f "node server/index.js" > /dev/null; then
    echo "❌ Failed to start server"
    exit 1
fi

echo "✅ Local server started on http://localhost:$SERVER_PORT"
echo "📋 Server details:"
echo "   - Local access: http://localhost:$SERVER_PORT"
echo "   - Process ID: $SERVER_PID"

# Test if the server is responding
echo "🧪 Testing server response..."
if curl -s -f "http://localhost:$SERVER_PORT/api/config" > /dev/null; then
    echo "✅ Server is responding correctly"
else
    echo "❌ Server is not responding on port $SERVER_PORT"
    echo "   Check the server logs for errors"
    exit 1
fi

echo ""
echo "🔗 Creating Cloudflare tunnel..."

# Cleanup function
cleanup() {
    echo "🛑 Stopping services..."
    if [ ! -z "$TUNNEL_PID" ]; then
        kill $TUNNEL_PID 2>/dev/null
    fi
    kill $SERVER_PID 2>/dev/null
    pkill -f "cloudflared tunnel" 2>/dev/null
    exit 0
}

# Set up cleanup trap
trap cleanup INT TERM

if [ "$USE_TEMP_TUNNEL" = true ]; then
    echo "🚀 Starting temporary Cloudflare tunnel for port $SERVER_PORT..."
    echo "   This will generate a random URL that you can use immediately"
    echo "   The tunnel will remain active until you stop this script"
    echo "   Press Ctrl+C to stop the tunnel"
    echo ""
    
    # Start temporary tunnel and capture output
    cloudflared tunnel --url http://localhost:$SERVER_PORT > /tmp/cloudflare-tunnel.log 2>&1 &
    TUNNEL_PID=$!
    
    # Wait for tunnel to establish and extract URL
    echo "⏳ Establishing tunnel connection..."
    sleep 10
    
    # Extract the tunnel URL from the logs
    TUNNEL_URL=$(grep -o "https://.*\.trycloudflare\.com" /tmp/cloudflare-tunnel.log | head -1)
    
    if [ ! -z "$TUNNEL_URL" ]; then
        echo "✅ Tunnel established successfully!"
        echo "🌐 Your app is accessible at: $TUNNEL_URL"
        echo ""
        echo "📋 Tunnel details:"
        echo "   - Public URL: $TUNNEL_URL"
        echo "   - Local URL: http://localhost:$SERVER_PORT"
        echo "   - Tunnel Process ID: $TUNNEL_PID"
        echo ""
        echo "   The tunnel will remain active until you stop this script"
        echo "   Press Ctrl+C to stop both the tunnel and server"
    else
        echo "❌ Failed to establish tunnel. Check the logs:"
        cat /tmp/cloudflare-tunnel.log
        cleanup
        exit 1
    fi
else
    # Use configured tunnel (requires setup)
    TUNNEL_NAME="claude-code-ui"
    echo "🚀 Starting configured Cloudflare tunnel '$TUNNEL_NAME' for port $SERVER_PORT..."
    echo "   Using your configured tunnel and domain"
    echo "   The tunnel will remain active until you stop this script"
    echo "   Press Ctrl+C to stop the tunnel"
    echo ""
    
    # Start the configured tunnel
    cloudflared tunnel run --local-service http://localhost:$SERVER_PORT $TUNNEL_NAME &
    TUNNEL_PID=$!
    
    # Wait for tunnel to establish
    sleep 5
    
    if pgrep -f "cloudflared tunnel run" > /dev/null; then
        echo "✅ Configured tunnel '$TUNNEL_NAME' is running"
        echo "🌐 Your app should be accessible at your configured domain"
        echo ""
        echo "📋 Tunnel details:"
        echo "   - Tunnel Name: $TUNNEL_NAME"
        echo "   - Local URL: http://localhost:$SERVER_PORT"
        echo "   - Tunnel Process ID: $TUNNEL_PID"
    else
        echo "❌ Failed to start configured tunnel. Make sure you have:"
        echo "   1. Created the tunnel: cloudflared tunnel create $TUNNEL_NAME"
        echo "   2. Configured DNS routing to your domain"
        echo "   3. Set up the tunnel configuration"
        cleanup
        exit 1
    fi
fi

# Keep the script running until interrupted
echo ""
echo "✨ Setup complete! Both server and tunnel are running."
echo "   Local access: http://localhost:$SERVER_PORT"
if [ ! -z "$TUNNEL_URL" ]; then
    echo "   Public access: $TUNNEL_URL"
fi
echo ""
echo "   Press Ctrl+C to stop both services"

# Wait for tunnel process to finish or be interrupted
wait $TUNNEL_PID 2>/dev/null

echo "🛑 Tunnel stopped. Local server is still running on http://localhost:$SERVER_PORT"
echo "   To stop the server: pkill -f 'node server/index.js'" 