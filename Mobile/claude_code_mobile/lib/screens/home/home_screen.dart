import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/common/server_connection_dialog.dart';
import '../project/project_selector_screen.dart';
import '../session/chat_screen.dart';
import '../session/file_explorer_screen.dart';
import '../session/git_screen.dart';
import '../session/shell_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: 'Chat',
    ),
    NavigationItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: 'Files',
    ),
    NavigationItem(
      icon: Icons.source_outlined,
      selectedIcon: Icons.source,
      label: 'Git',
    ),
    NavigationItem(
      icon: Icons.terminal_outlined,
      selectedIcon: Icons.terminal,
      label: 'Shell',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Load projects when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadProjects();
    });
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const ChatScreen();
      case 1:
        return const FileExplorerScreen();
      case 2:
        return const GitScreen();
      case 3:
        return const ShellScreen();
      default:
        return const ChatScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AppProvider>(
          builder: (context, provider, child) {
            if (provider.selectedProject == null) {
              return const Text('Claude Code Mobile');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.selectedProject!.displayName ??
                      provider.selectedProject!.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (provider.selectedSession != null)
                  Text(
                    provider.selectedSession!.title ?? 'New Session',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          // Server connection indicator
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  provider.isChatConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: provider.isChatConnected ? Colors.green : Colors.red,
                ),
                onPressed: () => _showServerConnectionDialog(context),
              );
            },
          ),
          // Project selector
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => _showProjectSelector(context),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          // Show error if exists
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => provider.loadProjects(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show loading
          if (provider.isLoading && provider.projects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading projects...'),
                ],
              ),
            );
          }

          // Show project selector if no project selected
          if (provider.selectedProject == null &&
              provider.projects.isNotEmpty) {
            return const ProjectSelectorScreen();
          }

          // Show empty state if no projects
          if (provider.projects.isEmpty && !provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Projects Found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Connect to your Claude Code server to see projects',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showServerConnectionDialog(context),
                    icon: const Icon(Icons.settings),
                    label: const Text('Configure Server'),
                  ),
                ],
              ),
            );
          }

          // Show main interface
          return _buildCurrentScreen();
        },
      ),
      bottomNavigationBar: Consumer<AppProvider>(
        builder: (context, provider, child) {
          // Only show navigation if project is selected
          if (provider.selectedProject == null) return const SizedBox.shrink();

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: _navigationItems.map((item) {
              final isSelected =
                  _navigationItems.indexOf(item) == _currentIndex;
              return BottomNavigationBarItem(
                icon: Icon(isSelected ? item.selectedIcon : item.icon),
                label: item.label,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _showProjectSelector(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProjectSelectorScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showServerConnectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ServerConnectionDialog(),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
