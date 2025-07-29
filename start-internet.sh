#!/bin/bash

echo "🚀 Starting Claude Code UI - Local Development"
echo "================================================================"

if pgrep -f "npm run dev" > /dev/null; then
    echo "⚠️  Application is already running. Stopping existing instance..."
    pkill -f "npm run dev"
    sleep 2
fi

echo "🌐 Starting development server..."
npm run dev > /tmp/claude-server.log 2>&1 &
SERVER_PID=$!

echo "⏳ Waiting for server to start..."
sleep 5

SERVER_PORT=$(grep -o "running on.*:[0-9]*" /tmp/claude-server.log | grep -o "[0-9]*" | tail -1)
if [ -z "$SERVER_PORT" ]; then
  echo "⚠️  Could not detect server port from logs, checking environment..."
  SERVER_PORT=${PORT:-3008}
fi

if ! pgrep -f "npm run dev" > /dev/null; then
    echo "❌ Failed to start server"
    exit 1
fi

echo "✅ Development server started on http://localhost:$SERVER_PORT"
echo "📋 Server details:"
echo "   - Local access: http://localhost:$SERVER_PORT"
echo "   - Process ID: $SERVER_PID"

echo "🧪 Testing server response..."
if curl -s -f "http://localhost:$SERVER_PORT" > /dev/null; then
    echo "✅ Server is responding correctly"
else
    echo "❌ Server is not responding on port $SERVER_PORT"
    echo "   Check the server logs for errors"
    exit 1
fi

cleanup() {
    echo "🛑 Stopping services..."
    kill $SERVER_PID 2>/dev/null
    exit 0
}

trap cleanup INT TERM

echo ""
echo "✨ Setup complete! Development server is running."
echo "   Local access: http://localhost:$SERVER_PORT"
echo ""
echo "   Press Ctrl+C to stop the server"

echo "   Server is running... Press Ctrl+C to stop"
while true; do
    sleep 1
done

echo "🛑 Server stopped."