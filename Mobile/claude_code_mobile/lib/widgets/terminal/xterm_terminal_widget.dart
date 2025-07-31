import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../providers/app_provider.dart';

/// XTerm-based terminal widget that behaves like the web version
/// Provides full terminal emulation with shell-based autocomplete
class XTermTerminalWidget extends StatefulWidget {
  final bool isShellMode;
  final VoidCallback? onDisconnected;

  const XTermTerminalWidget({
    super.key,
    this.isShellMode = false,
    this.onDisconnected,
  });

  @override
  State<XTermTerminalWidget> createState() => _XTermTerminalWidgetState();
}

class _XTermTerminalWidgetState extends State<XTermTerminalWidget> {
  Terminal? _terminal;
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initializeTerminal();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    _webSocketSubscription?.cancel();
    _webSocketChannel?.sink.close();
    // Note: Terminal doesn't have dispose() method in xterm 4.0.0
    _terminal = null;
  }

  void _initializeTerminal() {
    // Create terminal with configuration similar to web version
    _terminal = Terminal(maxLines: 10000);

    // Set up terminal input handler - send data directly to WebSocket like web version
    _terminal!.onOutput = (data) {
      if (_webSocketChannel != null && _isConnected) {
        _webSocketChannel!.sink.add(
          jsonEncode({'type': 'input', 'data': data}),
        );
      }
    };

    // Set up terminal resize handler like web version
    _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      if (_webSocketChannel != null && _isConnected) {
        _webSocketChannel!.sink.add(
          jsonEncode({'type': 'resize', 'cols': width, 'rows': height}),
        );
      }
    };

    // Auto-connect when terminal is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToBackend();
    });
  }

  void _connectToBackend() async {
    if (_isConnecting) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final project = appProvider.selectedProject;
    final session = appProvider.selectedSession;

    if (project == null) {
      if (mounted) {
        _terminal?.write(
          'No project selected. Please select a project first.\r\n',
        );
      }
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Determine WebSocket endpoint - same as web version
      final endpoint = widget.isShellMode ? 'shell' : 'terminal';

      // Connect to WebSocket - same backend as web version
      final uri = Uri.parse('wss://claude.grabr.cc/$endpoint');
      _webSocketChannel = WebSocketChannel.connect(uri);

      // Send initialization message - same format as web version
      _webSocketChannel!.sink.add(
        jsonEncode({
          'type': 'init',
          'projectPath': project.fullPath,
          'sessionId': session?.id,
          'hasSession': session != null,
        }),
      );

      // Listen for WebSocket messages
      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          if (mounted) {
            _terminal?.write('\r\n\x1b[31mWebSocket error: $error\x1b[0m\r\n');
            setState(() {
              _isConnected = false;
              _isConnecting = false;
            });
          }
        },
        onDone: () {
          if (mounted) {
            _terminal?.write('\r\n\x1b[33mConnection closed\x1b[0m\r\n');
            setState(() {
              _isConnected = false;
              _isConnecting = false;
            });
            widget.onDisconnected?.call();
          }
        },
      );

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (error) {
      if (mounted) {
        _terminal?.write('\r\n\x1b[31mConnection failed: $error\x1b[0m\r\n');
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'output':
          // Write terminal output directly like web version
          _terminal?.write(data['data']);
          break;
        case 'error':
          _terminal?.write('\r\n\x1b[31mError: ${data['message']}\x1b[0m\r\n');
          break;
      }
    } catch (error) {
      _terminal?.write('\r\n\x1b[31mMessage parse error: $error\x1b[0m\r\n');
    }
  }

  void _restart() {
    _cleanup();
    _initializeTerminal();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E), // Dark terminal background like web
      child: Column(
        children: [
          // Simple connection status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.circle : Icons.circle_outlined,
                  color: _isConnected ? Colors.green : Colors.orange,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.isShellMode ? 'Shell' : 'Terminal'} ${_isConnected ? '● Connected' : '○ Disconnected'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const Spacer(),
                if (!_isConnected)
                  IconButton(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    iconSize: 16,
                    color: Colors.white70,
                    tooltip: 'Reconnect',
                  ),
              ],
            ),
          ),
          // Terminal view - uses xterm widget like web version
          Expanded(
            child: _terminal != null
                ? Container(
                    color: const Color(0xFF1E1E1E),
                    child: TerminalView(
                      _terminal!,
                      // Theme similar to web version
                      theme: const TerminalTheme(
                        cursor: Color(0xFFFFFFFF),
                        selection: Color(0xFF264F78),
                        foreground: Color(0xFFD4D4D4),
                        background: Color(0xFF1E1E1E),
                        black: Color(0xFF000000),
                        red: Color(0xFFCD3131),
                        green: Color(0xFF0DBC79),
                        yellow: Color(0xFFE5E510),
                        blue: Color(0xFF2472C8),
                        magenta: Color(0xFFBC3FBC),
                        cyan: Color(0xFF11A8CD),
                        white: Color(0xFFE5E5E5),
                        brightBlack: Color(0xFF666666),
                        brightRed: Color(0xFFF14C4C),
                        brightGreen: Color(0xFF23D18B),
                        brightYellow: Color(0xFFF5F543),
                        brightBlue: Color(0xFF3B8EEA),
                        brightMagenta: Color(0xFFD670D6),
                        brightCyan: Color(0xFF29B8DB),
                        brightWhite: Color(0xFFFFFFFF),
                        // Required search colors for xterm 4.0.0
                        searchHitBackground: Color(0xFFFFFF00),
                        searchHitBackgroundCurrent: Color(0xFFFF8C00),
                        searchHitForeground: Color(0xFF000000),
                      ),
                      autofocus: true,
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
