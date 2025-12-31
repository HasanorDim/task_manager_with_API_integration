import 'package:flutter/material.dart';
import 'package:task_manager/model/task.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/connectivity_service.dart';
import '../utils/app_styles.dart';

class TaskFormScreen extends StatefulWidget {
  final bool isDarkMode;

  const TaskFormScreen({super.key, required this.isDarkMode});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _userIdController = TextEditingController();
  bool _isCompleted = false;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final OfflineQueueService _queueService = OfflineQueueService();
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void dispose() {
    _titleController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isConnected = await _connectivityService.checkConnection();

      // Create a temporary task for offline queue
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
        userId: int.parse(_userIdController.text),
        title: _titleController.text,
        completed: _isCompleted,
      );

      if (isConnected) {
        // Try to create task online
        try {
          await _apiService.createTask(
            userId: int.parse(_userIdController.text),
            title: _titleController.text,
            completed: _isCompleted,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task created successfully!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, true);
          }
        } catch (e) {
          // If online creation fails, queue it
          await _queueService.addToQueue(
            QueuedAction(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: QueueActionType.create,
              task: newTask,
              timestamp: DateTime.now(),
            ),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task queued for creation (offline)'),
                backgroundColor: AppColors.warning,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        // Offline - queue the action
        await _queueService.addToQueue(
          QueuedAction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: QueueActionType.create,
            task: newTask,
            timestamp: DateTime.now(),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task queued for creation (offline)'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              _buildHeader(context),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildFormCard(),
                          const SizedBox(height: 24),
                          _buildActionButtons(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Create New Task',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.cardDecoration(widget.isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Title *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: AppStyles.inputDecoration('Enter task title...'),
            style: TextStyle(
              color: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a task title';
              }
              if (value.length < 3) {
                return 'Title must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Minimum 3 characters',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Text(
            'User ID *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _userIdController,
            decoration: AppStyles.inputDecoration('Enter user ID...'),
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a user ID';
              }
              if (int.tryParse(value) == null) {
                return 'User ID must be a number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? AppColors.darkBackground
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mark as completed',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: widget.isDarkMode
                        ? AppColors.darkText
                        : AppColors.textPrimary,
                  ),
                ),
                Switch(
                  value: _isCompleted,
                  onChanged: (value) {
                    setState(() {
                      _isCompleted = value;
                    });
                  },
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDarkMode
                  ? AppColors.darkCard
                  : Colors.grey[200],
              foregroundColor: widget.isDarkMode
                  ? AppColors.darkText
                  : AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Task',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
