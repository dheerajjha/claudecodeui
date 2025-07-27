#!/bin/bash

# Start Claude Code UI with Internet Access
# This script starts the local server and creates an ngrok tunnel for internet access

echo "🚀 Starting Claude Code UI with Internet Access"
echo "================================================================"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Install it with: brew install ngrok"
    exit 1
fi

# Check ngrok authentication
echo "🔍 Checking ngrok setup..."
if ! ngrok config check &> /dev/null; then
    echo "⚠️  ngrok authentication not configured"
    echo "   For better reliability, sign up at https://ngrok.com and run:"
    echo "   ngrok authtoken YOUR_TOKEN"
    echo ""
    echo "   Continuing with basic setup (may have limitations)..."
    sleep 2
fi

# Check if the application is already running
if pgrep -f "node server/index.js" > /dev/null; then
    echo "⚠️  Application is already running. Stopping existing instance..."
    pkill -f "node server/index.js"
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
echo "🔗 Creating ngrok tunnel..."
echo "   Your app will be accessible at: https://striking-bass-crucial.ngrok-free.app"
echo "   The tunnel will remain active until you stop this script"
echo "   Press Ctrl+C to stop the tunnel"
echo ""

# Start ngrok tunnel with your static domain (this will block until stopped)
echo "🚀 Starting ngrok tunnel for port $SERVER_PORT..."
echo "🌐 Using your static domain: striking-bass-crucial.ngrok-free.app"
echo ""
ngrok http --url=striking-bass-crucial.ngrok-free.app $SERVER_PORT

# Cleanup when script is interrupted
trap 'echo "🛑 Stopping services..."; kill $SERVER_PID 2>/dev/null; exit 0' INT TERM

echo "🛑 Tunnel stopped. Local server is still running on http://localhost:$SERVER_PORT"
echo "   To stop the server: pkill -f 'node server/index.js'" 