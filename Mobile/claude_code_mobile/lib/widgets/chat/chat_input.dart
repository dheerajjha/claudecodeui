import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../providers/app_provider.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  List<File> _attachedImages = [];
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Image attachments preview
              if (_attachedImages.isNotEmpty)
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachedImages.length,
                    itemBuilder: (context, index) {
                      final image = _attachedImages[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                image,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // Input area
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Attachment button
                    IconButton(
                      onPressed: _showAttachmentOptions,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: provider.selectedProject == null
                              ? 'Select a project to start chatting'
                              : 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        enabled: provider.selectedProject != null,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Voice/Send button
                    if (_isTranscribing)
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_isRecording)
                      IconButton(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (_controller.text.trim().isNotEmpty ||
                        _attachedImages.isNotEmpty)
                      IconButton(
                        onPressed: provider.selectedProject != null
                            ? _sendMessage
                            : null,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: provider.selectedProject != null
                            ? _startRecording
                            : null,
                        icon: const Icon(Icons.mic),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _attachedImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
    });
  }

  Future<void> _startRecording() async {
    try {
      // Check permission
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        _showError('Microphone permission is required for voice messages');
        return;
      }

      // Start recording
      if (await _recorder.hasPermission()) {
        final path =
            '${Directory.systemTemp.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (_recordingPath != null) {
        await _transcribeAudio(_recordingPath!);
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    setState(() {
      _isTranscribing = true;
    });

    try {
      final provider = context.read<AppProvider>();
      final transcription = await provider.apiClient.transcribeAudio(
        File(audioPath),
      );

      if (transcription.isNotEmpty) {
        _controller.text = transcription;
        _focusNode.requestFocus();
      }
    } catch (e) {
      _showError('Failed to transcribe audio: $e');
    } finally {
      setState(() {
        _isTranscribing = false;
        _recordingPath = null;
      });

      // Clean up audio file
      try {
        if (_recordingPath != null) {
          File(_recordingPath!).deleteSync();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _attachedImages.isEmpty) return;

    final provider = context.read<AppProvider>();

    try {
      // Upload images if any
      List<String>? imageUrls;
      if (_attachedImages.isNotEmpty) {
        imageUrls = await provider.apiClient.uploadImages(
          provider.selectedProject!.name,
          _attachedImages,
        );
      }

      // Send message
      provider.sendMessage(message, images: imageUrls);

      // Clear input
      _controller.clear();
      setState(() {
        _attachedImages.clear();
      });
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
