import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/file_item.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  List<FileItem> _files = [];
  String? _selectedFile;
  String? _fileContent;
  bool _isLoadingFiles = false;
  bool _isLoadingFile = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    setState(() {
      _isLoadingFiles = true;
      _error = null;
    });

    try {
      final files = await provider.apiClient.getFiles(
        provider.selectedProject!.name,
      );
      if (mounted) {
        setState(() {
          _files = files;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load files: $e';
          _isLoadingFiles = false;
        });
      }
    }
  }

  Future<void> _loadFile(String filePath) async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    setState(() {
      _isLoadingFile = true;
      _selectedFile = filePath;
      _fileContent = null;
    });

    try {
      final response = await provider.apiClient.readFile(
        provider.selectedProject!.name,
        filePath,
      );
      if (mounted) {
        setState(() {
          _fileContent = response['content'] as String? ?? '';
          _isLoadingFile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load file: $e';
          _isLoadingFile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.selectedProject == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Select a project to browse files'),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with refresh button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder),
                  const SizedBox(width: 8),
                  Text(
                    'Files: ${provider.selectedProject!.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoadingFiles ? null : _loadFiles,
                  ),
                ],
              ),
            ),

            // Error banner
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 16,
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),

            // File browser
            Expanded(
              child: Row(
            children: [
                  // File tree (left panel)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                    ),
                  ),
                      child: _buildFileTree(),
                ),
              ),

                  // File content (right panel)
                  Expanded(flex: 2, child: _buildFileContent()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFileTree() {
    if (_isLoadingFiles) {
      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading files...'),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
            Text('No files found'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isSelected = _selectedFile == file.path;

        return ListTile(
          dense: true,
          leading: Icon(
            file.type == 'directory' ? Icons.folder : Icons.insert_drive_file,
            color: file.type == 'directory'
                ? Colors.blue
                : Theme.of(context).iconTheme.color,
                        ),
          title: Text(
            file.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
                    subtitle: file.type == 'file' && file.size != null
              ? Text(
                  '${(file.size! / 1024).toStringAsFixed(1)} KB',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          selected: isSelected,
          onTap: file.type == 'file' ? () => _loadFile(file.path) : null,
        );
      },
    );
  }

  Widget _buildFileContent() {
    if (_selectedFile == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Select a file to view its content'),
          ],
        ),
      );
    }

    if (_isLoadingFile) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading file...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // File header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Text(
            _selectedFile!.split('/').last,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // File content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _fileContent ?? 'No content available',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
