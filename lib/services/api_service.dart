import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:task_manager/model/task.dart';

class ApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';
  static const Duration timeout = Duration(seconds: 10);

  // Get all tasks
  Future<List<Task>> getTasks() async {
    try {
      // final response = await http
      //     .get(Uri.parse('$baseUrl/todos'))
      //     .timeout(timeout);

      final response = await http
          .get(
            Uri.parse('$baseUrl/todos'),
            headers: {
              'Content-Type': 'application/json',
              // 'Accept': 'application/json',
              // 'User-Agent': 'Dart/2.19 (dart:io)',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get single task
  Future<Task> getTask(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/todos/{$id}'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create new task
  Future<Task> createTask({
    required int userId,
    required String title,
    required bool completed,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/todos'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': userId,
              'title': title,
              'completed': completed,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update task
  Future<Task> updateTask(Task task) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/todos/${task.id}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(task.toJson()),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete task
  Future<void> deleteTask(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/todos/$id'))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
