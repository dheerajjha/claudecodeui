import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class GitScreen extends StatefulWidget {
  const GitScreen({super.key});

  @override
  State<GitScreen> createState() => _GitScreenState();
}

class _GitScreenState extends State<GitScreen> {
  Map<String, dynamic>? _gitStatus;
  List<String> _branches = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGitStatus();
    _loadBranches();
  }

  Future<void> _loadGitStatus() async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await provider.apiClient.getGitStatus(
        provider.selectedProject!.name,
      );
      if (mounted) {
        setState(() {
          _gitStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load Git status: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBranches() async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    try {
      final branches = await provider.apiClient.getBranches(
        provider.selectedProject!.name,
      );
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      // Branches loading is less critical, so we don't show error for this
      print('Failed to load branches: $e');
    }
  }

  Future<void> _stageFile(String filePath) async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    try {
      await provider.apiClient.stageFile(
        provider.selectedProject!.name,
        filePath,
      );
      _loadGitStatus(); // Refresh status
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to stage file: $e';
        });
      }
    }
  }

  Future<void> _unstageFile(String filePath) async {
    final provider = context.read<AppProvider>();
    if (provider.selectedProject == null) return;

    try {
      await provider.apiClient.unstageFile(
        provider.selectedProject!.name,
        filePath,
      );
      _loadGitStatus(); // Refresh status
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to unstage file: $e';
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
                Icon(Icons.source, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Select a project to view Git status'),
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
                  const Icon(Icons.source),
                  const SizedBox(width: 8),
                  Text(
                    'Git: ${provider.selectedProject!.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _loadGitStatus();
                            _loadBranches();
                          },
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

            // Git status content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading Git status...'),
                        ],
                      ),
                    )
                  : _buildGitStatus(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGitStatus() {
    if (_gitStatus == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Git status available'),
            SizedBox(height: 8),
            Text(
              'This might not be a Git repository',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch info
          if (_branches.isNotEmpty) ...[
            Text(
              'Current Branch',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_split, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _gitStatus?['branch'] ?? _branches.first,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Staged files
          if (_gitStatus?['staged'] != null &&
              (_gitStatus!['staged'] as List).isNotEmpty) ...[
            Text(
              'Staged Changes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildFileList(
              _gitStatus!['staged'] as List,
              Colors.green,
              true,
            ),
            const SizedBox(height: 24),
          ],

          // Modified files
          if (_gitStatus?['modified'] != null &&
              (_gitStatus!['modified'] as List).isNotEmpty) ...[
            Text(
              'Modified Files',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildFileList(
              _gitStatus!['modified'] as List,
              Colors.orange,
              false,
            ),
            const SizedBox(height: 24),
          ],

          // Untracked files
          if (_gitStatus?['untracked'] != null &&
              (_gitStatus!['untracked'] as List).isNotEmpty) ...[
            Text(
              'Untracked Files',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildFileList(
              _gitStatus!['untracked'] as List,
              Colors.grey,
              false,
            ),
            const SizedBox(height: 24),
          ],

          // Clean status
          if (_isRepoClean()) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Working tree clean',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          'No changes to commit',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFileList(List files, Color color, bool isStaged) {
    return files.map<Widget>((file) {
      final fileName = file is String ? file : file['file'] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.insert_drive_file, color: color, size: 16),
          title: Text(fileName, style: const TextStyle(fontSize: 14)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isStaged)
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => _stageFile(fileName),
                  tooltip: 'Stage file',
                )
              else
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () => _unstageFile(fileName),
                  tooltip: 'Unstage file',
                ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }).toList();
  }

  bool _isRepoClean() {
    if (_gitStatus == null) return false;

    final staged = _gitStatus!['staged'] as List? ?? [];
    final modified = _gitStatus!['modified'] as List? ?? [];
    final untracked = _gitStatus!['untracked'] as List? ?? [];

    return staged.isEmpty && modified.isEmpty && untracked.isEmpty;
  }
}
