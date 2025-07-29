import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/session.dart';

class SessionListDrawer extends StatelessWidget {
  const SessionListDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.selectedProject == null) {
            return const Center(child: Text('No project selected'));
          }

          final sessions = provider.selectedProject!.sessions ?? [];

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat Sessions',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              provider.selectedProject!.displayName ??
                                  provider.selectedProject!.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // New session button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.selectSession(
                        Session(
                          id: 'new-${DateTime.now().millisecondsSinceEpoch}',
                          title: 'New Session',
                          projectName: provider.selectedProject!.name,
                          createdAt: DateTime.now().toIso8601String(),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Session'),
                  ),
                ),
              ),

              // Sessions list
              Expanded(
                child: sessions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No sessions yet'),
                            SizedBox(height: 8),
                            Text(
                              'Start a new conversation to create your first session',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isSelected =
                              provider.selectedSession?.id == session.id;

                          return SessionListTile(
                            session: session,
                            isSelected: isSelected,
                            onTap: () {
                              provider.selectSession(session);
                              Navigator.of(context).pop();
                            },
                            onDelete: () =>
                                _deleteSession(context, provider, session),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteSession(
    BuildContext context,
    AppProvider provider,
    Session session,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Are you sure you want to delete "${session.title ?? session.id}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await provider.apiClient.deleteSession(
                  provider.selectedProject!.name,
                  session.id,
                );
                await provider.loadProjectSessions(
                  provider.selectedProject!.name,
                );

                // Clear selection if deleted session was selected
                if (provider.selectedSession?.id == session.id) {
                  provider.selectSession(
                    Session(
                      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
                      title: 'New Session',
                      projectName: provider.selectedProject!.name,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete session: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class SessionListTile extends StatelessWidget {
  final Session session;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SessionListTile({
    super.key,
    required this.session,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          session.title ?? 'Session ${session.id.substring(0, 8)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          _formatDate(session.createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withOpacity(0.3),
          child: Icon(
            Icons.chat_bubble_outline,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          color: Colors.red.withOpacity(0.7),
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
