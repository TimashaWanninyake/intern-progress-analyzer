/*
AI Service - Flutter Frontend Integration
========================================

This service handles all AI-related API communications between the Flutter
frontend and the Python backend AI system.

Features:
- Multi-provider AI report generation (OLLAMA, GPT-4, Claude)
- Provider status monitoring and health checks
- Report history and management
- Cost estimation and optimization
- Real-time progress tracking
- Error handling and fallback mechanisms

Usage:
  final aiService = AIService();
  final providers = await aiService.getAvailableProviders();
  final report = await aiService.generateReport('ollama', internId, 'weekly');
*/

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// AI Provider information model
class AIProvider {
  final String name;
  final String displayName;
  final String description;
  final bool available;
  final List<String> models;
  final String cost;
  final String speed;
  final String? lastError;

  AIProvider({
    required this.name,
    required this.displayName,
    required this.description,
    required this.available,
    required this.models,
    required this.cost,
    required this.speed,
    this.lastError,
  });

  factory AIProvider.fromJson(Map<String, dynamic> json) {
    return AIProvider(
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? '',
      description: json['description'] ?? '',
      available: json['available'] ?? false,
      models: List<String>.from(json['models'] ?? []),
      cost: json['cost'] ?? 'Unknown',
      speed: json['speed'] ?? 'Unknown',
      lastError: json['last_error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'description': description,
      'available': available,
      'models': models,
      'cost': cost,
      'speed': speed,
      'last_error': lastError,
    };
  }

  @override
  String toString() => 'AIProvider(name: $name, available: $available)';
}

/// AI Report model for generated reports
class AIReport {
  final int? reportId;
  final String reportType;
  final String providerUsed;
  final bool fallbackUsed;
  final String? originalProvider;
  final DateTime generatedAt;
  final Map<String, dynamic> content;
  final Map<String, dynamic>? metadata;
  final bool success;
  final String? error;

  AIReport({
    this.reportId,
    required this.reportType,
    required this.providerUsed,
    this.fallbackUsed = false,
    this.originalProvider,
    required this.generatedAt,
    required this.content,
    this.metadata,
    this.success = true,
    this.error,
  });

  factory AIReport.fromJson(Map<String, dynamic> json) {
    return AIReport(
      reportId: json['report_id'],
      reportType: json['report_type'] ?? 'weekly',
      providerUsed: json['provider_used'] ?? 'unknown',
      fallbackUsed: json['fallback_used'] ?? false,
      originalProvider: json['original_provider'],
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
      content: json['content'] ?? {},
      metadata: json['metadata'],
      success: json['success'] ?? true,
      error: json['error'],
    );
  }

  String get summary => content['summary'] ?? 'No summary available';
  List<String> get strengths => List<String>.from(content['strengths'] ?? []);
  List<String> get weaknesses => List<String>.from(content['weaknesses'] ?? []);
  List<String> get recommendations => List<String>.from(content['recommendations'] ?? []);
  int get performanceScore => content['performance_score'] ?? 0;

  @override
  String toString() => 'AIReport(id: $reportId, type: $reportType, provider: $providerUsed)';
}

/// Report generation request model
class ReportRequest {
  final String provider;
  final int internId;
  final int? projectId;
  final String reportType;
  final Map<String, String>? dateRange;
  final bool useFallback;
  final int? templateId;

  ReportRequest({
    required this.provider,
    required this.internId,
    this.projectId,
    required this.reportType,
    this.dateRange,
    this.useFallback = true,
    this.templateId,
  });

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'intern_id': internId,
      if (projectId != null) 'project_id': projectId,
      'report_type': reportType,
      if (dateRange != null) 'date_range': dateRange,
      'use_fallback': useFallback,
      if (templateId != null) 'template_id': templateId,
    };
  }
}

/// Cost estimation model
class CostEstimate {
  final String provider;
  final int estimatedInputTokens;
  final int estimatedOutputTokens;
  final int totalTokens;
  final double estimatedCostUsd;
  final bool isFree;

  CostEstimate({
    required this.provider,
    required this.estimatedInputTokens,
    required this.estimatedOutputTokens,
    required this.totalTokens,
    required this.estimatedCostUsd,
    required this.isFree,
  });

  factory CostEstimate.fromJson(Map<String, dynamic> json) {
    return CostEstimate(
      provider: json['provider'] ?? '',
      estimatedInputTokens: json['estimated_input_tokens'] ?? 0,
      estimatedOutputTokens: json['estimated_output_tokens'] ?? 0,
      totalTokens: json['total_tokens'] ?? 0,
      estimatedCostUsd: (json['estimated_cost_usd'] ?? 0.0).toDouble(),
      isFree: json['is_free'] ?? false,
    );
  }
}

/// Main AI Service class
class AIService {
  static const String _baseUrl = 'http://127.0.0.1:5000'; // Backend URL
  static const int _timeoutDuration = 120; // 2 minutes for AI generation

  // Singleton instance
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  String? _authToken;

  /// Set authentication token for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Get common headers for API requests
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['x-access-token'] = _authToken!;
    }
    return headers;
  }

  /// Get available AI providers and their status
  Future<List<AIProvider>> getAvailableProviders() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai/providers'),
        headers: _headers,
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> providersJson = data['providers'] ?? [];
          return providersJson.map((json) => AIProvider.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to get providers');
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting AI providers: $e');
      rethrow;
    }
  }

  /// Generate AI report with specified provider
  Future<AIReport> generateReport(ReportRequest request) async {
    try {
      debugPrint('Generating AI report: ${request.reportType} for intern ${request.internId} using ${request.provider}');

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/generate-report'),
        headers: _headers,
        body: json.encode(request.toJson()),
      ).timeout(Duration(seconds: _timeoutDuration));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return AIReport.fromJson(data);
        } else {
          return AIReport(
            reportType: request.reportType,
            providerUsed: request.provider,
            generatedAt: DateTime.now(),
            content: {},
            success: false,
            error: data['message'] ?? 'Report generation failed',
          );
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${data['message'] ?? response.body}');
      }
    } catch (e) {
      debugPrint('Error generating AI report: $e');
      return AIReport(
        reportType: request.reportType,
        providerUsed: request.provider,
        generatedAt: DateTime.now(),
        content: {},
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get report history with filtering and pagination
  Future<Map<String, dynamic>> getReportHistory({
    int? internId,
    int? projectId,
    String? provider,
    String? reportType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (internId != null) queryParams['intern_id'] = internId.toString();
      if (projectId != null) queryParams['project_id'] = projectId.toString();
      if (provider != null) queryParams['provider'] = provider;
      if (reportType != null) queryParams['report_type'] = reportType;

      final uri = Uri.parse('$_baseUrl/ai/reports/history').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> reportsJson = data['reports'] ?? [];
          final reports = reportsJson.map((json) => AIReport.fromJson(json)).toList();

          return {
            'reports': reports,
            'pagination': data['pagination'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to get report history');
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting report history: $e');
      rethrow;
    }
  }

  /// Get health status of AI providers
  Future<Map<String, dynamic>> getProviderHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai/health'),
        headers: _headers,
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['health'];
        } else {
          throw Exception(data['message'] ?? 'Failed to get provider health');
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting provider health: $e');
      rethrow;
    }
  }

  /// Estimate cost for generating a report
  Future<CostEstimate> estimateReportCost({
    required String provider,
    required int internId,
    int? projectId,
    Map<String, String>? dateRange,
  }) async {
    try {
      final requestBody = {
        'provider': provider,
        'intern_id': internId,
        if (projectId != null) 'project_id': projectId,
        if (dateRange != null) 'date_range': dateRange,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/cost-estimate'),
        headers: _headers,
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return CostEstimate.fromJson(data['cost_estimate']);
        } else {
          throw Exception(data['message'] ?? 'Failed to estimate cost');
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error estimating report cost: $e');
      rethrow;
    }
  }

  /// Submit feedback for a generated report
  Future<bool> submitReportFeedback({
    required int reportId,
    int? rating,
    String? feedback,
    String feedbackType = 'general',
  }) async {
    try {
      final requestBody = {
        'report_id': reportId,
        if (rating != null) 'rating': rating,
        if (feedback != null) 'feedback': feedback,
        'feedback_type': feedbackType,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/feedback'),
        headers: _headers,
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        debugPrint('Failed to submit feedback: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      return false;
    }
  }

  /// Check if a specific provider is available
  Future<bool> isProviderAvailable(String providerName) async {
    try {
      final providers = await getAvailableProviders();
      final provider = providers.firstWhere(
        (p) => p.name == providerName,
        orElse: () => AIProvider(
          name: '',
          displayName: '',
          description: '',
          available: false,
          models: [],
          cost: '',
          speed: '',
        ),
      );
      return provider.available;
    } catch (e) {
      debugPrint('Error checking provider availability: $e');
      return false;
    }
  }

  /// Get recommended provider based on criteria
  Future<String?> getRecommendedProvider({
    String priority = 'balanced', // 'cost', 'quality', 'speed', 'balanced'
  }) async {
    try {
      final providers = await getAvailableProviders();
      final availableProviders = providers.where((p) => p.available).toList();

      if (availableProviders.isEmpty) return null;

      switch (priority) {
        case 'cost':
          // Prefer free providers (OLLAMA)
          final freeProvider = availableProviders.firstWhere(
            (p) => p.cost.toLowerCase().contains('free'),
            orElse: () => availableProviders.first,
          );
          return freeProvider.name;

        case 'quality':
          // Prefer advanced providers (GPT-4, Claude, then OLLAMA)
          for (final providerName in ['gpt4', 'claude', 'ollama']) {
            final provider = availableProviders.firstWhere(
              (p) => p.name == providerName,
              orElse: () => AIProvider(
                name: '',
                displayName: '',
                description: '',
                available: false,
                models: [],
                cost: '',
                speed: '',
              ),
            );
            if (provider.available) return provider.name;
          }
          break;

        case 'speed':
          // Prefer fast providers (OLLAMA first, then others)
          final fastProvider = availableProviders.firstWhere(
            (p) => p.speed.toLowerCase().contains('fast'),
            orElse: () => availableProviders.first,
          );
          return fastProvider.name;

        case 'balanced':
        default:
          // Return first available provider
          return availableProviders.first.name;
      }

      return availableProviders.isNotEmpty ? availableProviders.first.name : null;
    } catch (e) {
      debugPrint('Error getting recommended provider: $e');
      return null;
    }
  }

  /// Validate report request before sending
  bool validateReportRequest(ReportRequest request) {
    if (request.internId <= 0) return false;
    if (!['weekly', 'monthly', 'project_summary'].contains(request.reportType)) return false;
    if (!['ollama', 'gpt4', 'claude'].contains(request.provider)) return false;
    return true;
  }

  /// Generate multiple reports with different providers for comparison
  Future<List<AIReport>> generateComparisonReports(
    int internId, {
    int? projectId,
    String reportType = 'weekly',
    Map<String, String>? dateRange,
    List<String>? providers,
  }) async {
    try {
      // Use default providers if none specified
      providers ??= ['ollama', 'gpt4', 'claude'];

      // Get available providers
      final availableProviders = await getAvailableProviders();
      final availableNames = availableProviders
          .where((p) => p.available)
          .map((p) => p.name)
          .toList();

      // Filter requested providers to only available ones
      final validProviders = providers.where((p) => availableNames.contains(p)).toList();

      if (validProviders.isEmpty) {
        throw Exception('No requested providers are available');
      }

      // Generate reports concurrently
      final futures = validProviders.map((provider) async {
        final request = ReportRequest(
          provider: provider,
          internId: internId,
          projectId: projectId,
          reportType: reportType,
          dateRange: dateRange,
          useFallback: false, // No fallback for comparison
        );

        return await generateReport(request);
      }).toList();

      final reports = await Future.wait(futures);
      return reports.where((r) => r.success).toList();
    } catch (e) {
      debugPrint('Error generating comparison reports: $e');
      rethrow;
    }
  }
}