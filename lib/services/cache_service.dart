import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/model/task.dart';

class CacheService {
  static const String _tasksKey = 'cached_tasks';
  static const String _darkModeKey = 'dark_mode';
  static const String _viewModeKey = 'view_mode';
  static const String _defaultFilterKey = 'default_filter';

  // Cache tasks
  Future<void> cacheTasks(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(
        tasks.map((task) => task.toJson()).toList(),
      );
      await prefs.setString(_tasksKey, jsonString);
    } catch (e) {
      throw Exception('Failed to cache tasks: $e');
    }
  }

  // Get cached tasks
  Future<List<Task>> getCachedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_tasksKey);

      if (jsonString == null) {
        return [];
      }

      final List<dynamic> jsonData = json.decode(jsonString);
      return jsonData.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load cached tasks: $e');
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksKey);
  }

  // Dark mode preference
  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  // View mode preference (list/grid)
  Future<void> setViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode);
  }

  Future<String> getViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewModeKey) ?? 'list';
  }

  // Default filter preference
  Future<void> setDefaultFilter(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultFilterKey, filter);
  }

  Future<String> getDefaultFilter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultFilterKey) ?? 'all';
  }
}
