import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/model/task.dart';

enum QueueActionType { create, update, delete }

class QueuedAction {
  final String id;
  final QueueActionType type;
  final Task? task;
  final int? taskId;
  final DateTime timestamp;

  QueuedAction({
    required this.id,
    required this.type,
    this.task,
    this.taskId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'task': task?.toJson(),
      'taskId': taskId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'],
      type: QueueActionType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      task: json['task'] != null ? Task.fromJson(json['task']) : null,
      taskId: json['taskId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class OfflineQueueService {
  static const String _queueKey = 'offline_queue';

  Future<void> addToQueue(QueuedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    queue.add(action);

    final jsonList = queue.map((a) => a.toJson()).toList();
    await prefs.setString(_queueKey, json.encode(jsonList));
  }

  Future<List<QueuedAction>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_queueKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => QueuedAction.fromJson(json)).toList();
  }

  Future<void> removeFromQueue(String actionId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    queue.removeWhere((action) => action.id == actionId);

    final jsonList = queue.map((a) => a.toJson()).toList();
    await prefs.setString(_queueKey, json.encode(jsonList));
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<int> getQueueCount() async {
    final queue = await getQueue();
    return queue.length;
  }
}
