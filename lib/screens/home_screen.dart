import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:task_manager/model/task.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/offline_queue_service.dart';
import '../services/connectivity_service.dart';
import '../utils/app_styles.dart';
import '../widgets/shimmer_loading.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

enum FilterType { all, completed, pending }

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();
  final OfflineQueueService _queueService = OfflineQueueService();
  final ConnectivityService _connectivityService = ConnectivityService();

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  FilterType _filterType = FilterType.all;
  String _viewMode = 'list';
  bool _isLoading = true;
  bool _isConnected = true;
  int _queuedActionsCount = 0;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  // User filter
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadTasks();
    _setupConnectivityListener();
    _setupScrollListener();
    _setupFabAnimation();
    _checkQueuedActions();
  }

  void _setupFabAnimation() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.bounceOut,
    );
    _fabAnimationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreTasks();
      }
    });
  }

  void _setupConnectivityListener() {
    _connectivityService.connectionStatus.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });

      if (isConnected) {
        _syncOfflineActions();
        _loadTasks();
      }
    });
  }

  Future<void> _checkQueuedActions() async {
    final count = await _queueService.getQueueCount();
    setState(() {
      _queuedActionsCount = count;
    });
  }

  Future<void> _syncOfflineActions() async {
    final queue = await _queueService.getQueue();

    for (var action in queue) {
      try {
        switch (action.type) {
          case QueueActionType.create:
            if (action.task != null) {
              await _apiService.createTask(
                userId: action.task!.userId,
                title: action.task!.title,
                completed: action.task!.completed,
              );
            }
            break;
          case QueueActionType.update:
            if (action.task != null) {
              await _apiService.updateTask(action.task!);
            }
            break;
          case QueueActionType.delete:
            if (action.taskId != null) {
              await _apiService.deleteTask(action.taskId!);
            }
            break;
        }
        await _queueService.removeFromQueue(action.id);
      } catch (e) {
        // Keep in queue if failed
        print('Failed to sync action: $e');
      }
    }

    _checkQueuedActions();
    _showSnackBar('Offline actions synced successfully', AppColors.success);
  }

  Future<void> _loadPreferences() async {
    final viewMode = await _cacheService.getViewMode();
    final filter = await _cacheService.getDefaultFilter();
    setState(() {
      _viewMode = viewMode;
      _filterType = _parseFilterType(filter);
    });
  }

  FilterType _parseFilterType(String filter) {
    switch (filter) {
      case 'completed':
        return FilterType.completed;
      case 'pending':
        return FilterType.pending;
      default:
        return FilterType.all;
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMoreData = true;
    });

    try {
      final tasks = await _apiService.getTasks();
      await _cacheService.cacheTasks(tasks);
      setState(() {
        _allTasks = tasks;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      try {
        final cachedTasks = await _cacheService.getCachedTasks();
        setState(() {
          _allTasks = cachedTasks;
          _applyFilters();
          _isLoading = false;
        });
      } catch (cacheError) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreTasks() async {
    if (!_hasMoreData || _isLoading) return;

    // Simulate pagination with local data
    final startIndex = (_currentPage + 1) * _pageSize;
    if (startIndex >= _allTasks.length) {
      setState(() {
        _hasMoreData = false;
      });
      return;
    }

    setState(() {
      _currentPage++;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _allTasks;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (task) =>
                task.title.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply status filter
    switch (_filterType) {
      case FilterType.completed:
        filtered = filtered.where((task) => task.completed).toList();
        break;
      case FilterType.pending:
        filtered = filtered.where((task) => !task.completed).toList();
        break;
      case FilterType.all:
        break;
    }

    // Apply user filter
    if (_selectedUserId != null) {
      filtered = filtered
          .where((task) => task.userId == _selectedUserId)
          .toList();
    }

    // Apply pagination
    final endIndex = (_currentPage + 1) * _pageSize;
    if (endIndex < filtered.length) {
      setState(() {
        _filteredTasks = filtered.take(endIndex).toList();
        _hasMoreData = true;
      });
    } else {
      setState(() {
        _filteredTasks = filtered;
        _hasMoreData = false;
      });
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_isConnected) {
      try {
        await _apiService.deleteTask(task.id);
        _showSnackBar('Task deleted successfully', AppColors.success);
      } catch (e) {
        _showSnackBar('Failed to delete task', AppColors.error);
        return;
      }
    } else {
      await _queueService.addToQueue(
        QueuedAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: QueueActionType.delete,
          taskId: task.id,
          timestamp: DateTime.now(),
        ),
      );
      _checkQueuedActions();
      _showSnackBar('Delete queued (offline)', AppColors.warning);
    }

    setState(() {
      _allTasks.removeWhere((t) => t.id == task.id);
      _applyFilters();
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showUserFilterDialog() {
    final userIds = _allTasks.map((t) => t.userId).toSet().toList()..sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter by User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Users'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: _selectedUserId,
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ...userIds.map(
                (userId) => ListTile(
                  title: Text('User $userId'),
                  leading: Radio<int?>(
                    value: userId,
                    groupValue: _selectedUserId,
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: widget.isDarkMode
            ? AppStyles.darkGradientBackground
            : AppStyles.gradientBackground,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? AppColors.darkBackground
                        : Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: !_isLoading
                      ? const ShimmerLoadingList()
                      : Column(
                          children: [
                            if (!_isConnected || _queuedActionsCount > 0)
                              _buildOfflineIndicator(),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _loadTasks,
                                color: AppColors.primary,
                                child: _buildTaskList(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    TaskFormScreen(isDarkMode: widget.isDarkMode),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
              ),
            );
            if (result == true) {
              _loadTasks();
            }
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  //Header Widget
  Widget _buildHeader() {
    final completedCount = _allTasks.where((t) => t.completed).length;
    final totalCount = _allTasks.length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Tasks',
                    style: AppStyles.heading1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedCount of $totalCount completed',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StatisticsScreen(
                            tasks: _allTasks,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bar_chart, color: Colors.white),
                    tooltip: 'Statistics',
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            isDarkMode: widget.isDarkMode,
                            onThemeChanged: widget.onThemeChanged,
                          ),
                        ),
                      );
                      _loadPreferences();
                    },
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildFilterRow(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(child: _buildFilterTabs()),
        const SizedBox(width: 12),
        _buildUserFilterButton(),
        const SizedBox(width: 8),
        _buildViewModeButton(),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildFilterTab('All', FilterType.all),
          _buildFilterTab('Done', FilterType.completed),
          _buildFilterTab('Pending', FilterType.pending),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, FilterType type) {
    final isSelected = _filterType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterType = type;
            _currentPage = 0;
            _applyFilters();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserFilterButton() {
    return Container(
      decoration: BoxDecoration(
        color: _selectedUserId != null
            ? Colors.white
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          Icons.person,
          color: _selectedUserId != null ? AppColors.primary : Colors.white,
        ),
        onPressed: _showUserFilterDialog,
        tooltip: 'Filter by User',
      ),
    );
  }

  Widget _buildViewModeButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          _viewMode == 'list' ? Icons.grid_view : Icons.view_list,
          color: Colors.white,
        ),
        onPressed: () {
          setState(() {
            _viewMode = _viewMode == 'list' ? 'grid' : 'list';
          });
          _cacheService.setViewMode(_viewMode);
        },
        tooltip: _viewMode == 'list' ? 'Grid View' : 'List View',
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isConnected ? AppColors.warning : AppColors.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_isConnected ? Icons.sync : Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isConnected
                  ? 'Syncing $_queuedActionsCount offline action(s)...'
                  : 'No internet connection - Working offline',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_filteredTasks.isEmpty) {
      return _buildEmptyState();
    }

    return _viewMode == 'list' ? _buildListView() : _buildGridView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedUserId != null
                ? 'No tasks found'
                : 'No tasks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedUserId != null
                ? 'Try a different filter'
                : 'Tap the + button to create a task',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTasks.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredTasks.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        return _buildSlidableTaskCard(_filteredTasks[index]);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) =>
          _buildGridTaskCard(_filteredTasks[index]),
    );
  }

  Widget _buildSlidableTaskCard(Task task) {
    return Slidable(
      key: Key(task.id.toString()),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => _deleteTask(task),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
      child: _buildTaskCard(task),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Hero(
      tag: 'task_${task.id}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppStyles.cardDecoration(widget.isDarkMode),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.completed ? AppColors.success : Colors.transparent,
                border: task.completed
                    ? null
                    : Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: task.completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: task.completed ? TextDecoration.lineThrough : null,
                color: task.completed
                    ? Colors.grey
                    : (widget.isDarkMode
                          ? AppColors.darkText
                          : AppColors.textPrimary),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'User ${task.userId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () async {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      TaskDetailScreen(
                        task: task,
                        isDarkMode: widget.isDarkMode,
                        onTaskUpdated: _loadTasks,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridTaskCard(Task task) {
    return Hero(
      tag: 'task_${task.id}',
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    TaskDetailScreen(
                      task: task,
                      isDarkMode: widget.isDarkMode,
                      onTaskUpdated: _loadTasks,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppStyles.cardDecoration(widget.isDarkMode),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.completed
                            ? AppColors.success
                            : Colors.transparent,
                        border: task.completed
                            ? null
                            : Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: task.completed
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () => _deleteTask(task),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.completed
                          ? Colors.grey
                          : (widget.isDarkMode
                                ? AppColors.darkText
                                : AppColors.textPrimary),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'User ${task.userId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
}
