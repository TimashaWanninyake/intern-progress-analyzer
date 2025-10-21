"""
AI Reports API - Multi-Provider AI Report Generation
==================================================

This module provides comprehensive API endpoints for AI-powered intern progress analysis.
Supports multiple AI providers (OLLAMA, GPT-4, Claude) with unified interface.

Features:
- Multi-provider AI report generation
- Report history and templates
- Provider health monitoring
- Cost estimation and optimization
- Feedback collection and analysis

Endpoints:
- POST /generate-report - Generate AI report with provider selection
- GET /providers - Get available AI providers and status
- GET /reports/history - Get historical reports
- GET /templates - Get report templates
- POST /feedback - Submit report feedback
"""

import json
import logging
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from utils.db import get_db_connection
from utils.token_helper import token_required
from utils.ai_providers.ai_manager import AIManager

logger = logging.getLogger(__name__)
ai_routes = Blueprint('ai_routes', __name__)

# Initialize AI Manager
ai_manager = AIManager()

@ai_routes.route('/providers', methods=['GET'])
@token_required
def get_ai_providers(user):
    """
    Get available AI providers with their status and capabilities
    
    Returns:
        JSON response with provider information
    """
    try:
        # Only supervisors and admins can access AI features
        if user['role'] not in ['supervisor', 'admin']:
            return jsonify({
                'success': False, 
                'message': 'Unauthorized. AI reports are available for supervisors only.'
            }), 403
        
        providers = ai_manager.get_available_providers()
        
        return jsonify({
            'success': True,
            'providers': providers,
            'default_provider': ai_manager.default_provider,
            'fallback_order': ai_manager.fallback_order
        })
        
    except Exception as e:
        logger.error(f"Error getting AI providers: {e}")
        return jsonify({
            'success': False,
            'message': 'Failed to retrieve AI provider information',
            'error': str(e)
        }), 500

@ai_routes.route('/generate-report', methods=['POST'])
@token_required
def generate_ai_report(user):
    """
    Generate AI-powered intern progress report
    
    Expected JSON payload:
    {
        "provider": "ollama|gpt4|claude",
        "intern_id": 123,
        "project_id": 456,
        "report_type": "weekly|monthly|project_summary",
        "date_range": {
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        },
        "use_fallback": true,
        "template_id": 1 (optional)
    }
    
    Returns:
        JSON response with generated report
    """
    try:
        # Authorization check
        if user['role'] not in ['supervisor', 'admin']:
            return jsonify({
                'success': False,
                'message': 'Unauthorized. AI reports are available for supervisors only.'
            }), 403
        
        # Parse request data
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
        
        # Validate required fields
        required_fields = ['provider', 'intern_id', 'report_type']
        missing_fields = [field for field in required_fields if field not in data]
        if missing_fields:
            return jsonify({
                'success': False,
                'message': f'Missing required fields: {", ".join(missing_fields)}'
            }), 400
        
        provider_name = data['provider']
        intern_id = data['intern_id']
        project_id = data.get('project_id')
        report_type = data['report_type']
        use_fallback = data.get('use_fallback', True)
        date_range = data.get('date_range', {})
        
        # Validate report type
        valid_report_types = ['weekly', 'monthly', 'project_summary']
        if report_type not in valid_report_types:
            return jsonify({
                'success': False,
                'message': f'Invalid report type. Must be one of: {", ".join(valid_report_types)}'
            }), 400
        
        # Get intern data from database
        intern_data = _get_intern_data(intern_id, project_id, date_range, user['id'])
        if not intern_data:
            return jsonify({
                'success': False,
                'message': 'No data found for the specified intern and date range'
            }), 404
        
        # Generate AI report
        logger.info(f"Generating {report_type} report for intern {intern_id} using {provider_name}")
        
        report = ai_manager.generate_report(
            provider_name=provider_name,
            intern_data=intern_data,
            report_type=report_type,
            use_fallback=use_fallback
        )
        
        if report.get('success', True):
            # Save report to database
            report_id = _save_report_to_database(report, user['id'], intern_id, project_id)
            report['report_id'] = report_id
            
            logger.info(f"AI report generated successfully with ID {report_id}")
            return jsonify(report)
        else:
            logger.error(f"AI report generation failed: {report.get('error')}")
            return jsonify(report), 500
            
    except Exception as e:
        logger.error(f"Error generating AI report: {e}")
        return jsonify({
            'success': False,
            'message': 'Failed to generate AI report',
            'error': str(e)
        }), 500

@ai_routes.route('/reports/history', methods=['GET'])
@token_required
def get_report_history(user):
    """
    Get historical AI reports with filtering and pagination
    
    Query parameters:
    - intern_id: Filter by intern ID
    - project_id: Filter by project ID
    - provider: Filter by AI provider
    - report_type: Filter by report type
    - limit: Number of results (default: 20)
    - offset: Pagination offset (default: 0)
    
    Returns:
        JSON response with report history
    """
    try:
        if user['role'] not in ['supervisor', 'admin']:
            return jsonify({
                'success': False,
                'message': 'Unauthorized'
            }), 403
        
        # Parse query parameters
        intern_id = request.args.get('intern_id', type=int)
        project_id = request.args.get('project_id', type=int)
        provider = request.args.get('provider')
        report_type = request.args.get('report_type')
        limit = request.args.get('limit', 20, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        # Build query
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        where_conditions = ["1=1"]  # Base condition
        params = []
        
        # Add filters based on user role
        if user['role'] == 'supervisor':
            # Supervisors can only see reports for their projects
            where_conditions.append("ar.project_id IN (SELECT id FROM projects WHERE supervisor_id = %s)")
            params.append(user['id'])
        
        if intern_id:
            where_conditions.append("ar.intern_id = %s")
            params.append(intern_id)
        
        if project_id:
            where_conditions.append("ar.project_id = %s")
            params.append(project_id)
            
        if provider:
            where_conditions.append("ar.provider_used = %s")
            params.append(provider)
            
        if report_type:
            where_conditions.append("ar.report_type = %s")
            params.append(report_type)
        
        # Execute query
        query = f"""
        SELECT 
            ar.*,
            u.name as intern_name,
            p.name as project_name,
            su.name as supervisor_name
        FROM ai_reports ar
        LEFT JOIN users u ON ar.intern_id = u.id
        LEFT JOIN projects p ON ar.project_id = p.id
        LEFT JOIN users su ON ar.generated_by = su.id
        WHERE {' AND '.join(where_conditions)}
        ORDER BY ar.generated_at DESC
        LIMIT %s OFFSET %s
        """
        
        params.extend([limit, offset])
        cursor.execute(query, params)
        reports = cursor.fetchall()
        
        # Get total count
        count_query = f"""
        SELECT COUNT(*) as total
        FROM ai_reports ar
        WHERE {' AND '.join(where_conditions[:-2])}  # Exclude LIMIT/OFFSET conditions
        """
        cursor.execute(count_query, params[:-2])
        total_count = cursor.fetchone()['total']
        
        cursor.close()
        conn.close()
        
        # Parse JSON fields
        for report in reports:
            if report['content']:
                try:
                    report['content'] = json.loads(report['content'])
                except json.JSONDecodeError:
                    pass
            if report['metadata']:
                try:
                    report['metadata'] = json.loads(report['metadata'])
                except json.JSONDecodeError:
                    pass
        
        return jsonify({
            'success': True,
            'reports': reports,
            'pagination': {
                'total': total_count,
                'limit': limit,
                'offset': offset,
                'has_more': offset + limit < total_count
            }
        })
        
    except Exception as e:
        logger.error(f"Error getting report history: {e}")
        return jsonify({
            'success': False,
            'message': 'Failed to retrieve report history',
            'error': str(e)
        }), 500

@ai_routes.route('/health', methods=['GET'])
@token_required
def get_provider_health(user):
    """
    Get health status of all AI providers
    
    Returns:
        JSON response with provider health information
    """
    try:
        if user['role'] not in ['supervisor', 'admin']:
            return jsonify({
                'success': False,
                'message': 'Unauthorized'
            }), 403
        
        health_status = ai_manager.get_provider_health()
        
        return jsonify({
            'success': True,
            'health': health_status
        })
        
    except Exception as e:
        logger.error(f"Error getting provider health: {e}")
        return jsonify({
            'success': False,
            'message': 'Failed to get provider health status',
            'error': str(e)
        }), 500

@ai_routes.route('/cost-estimate', methods=['POST'])
@token_required
def estimate_report_cost(user):
    """
    Estimate cost for generating a report with a specific provider
    
    Expected JSON payload:
    {
        "provider": "ollama|gpt4|claude",
        "intern_id": 123,
        "date_range": {
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    }
    
    Returns:
        JSON response with cost estimation
    """
    try:
        if user['role'] not in ['supervisor', 'admin']:
            return jsonify({
                'success': False,
                'message': 'Unauthorized'
            }), 403
        
        data = request.get_json()
        if not data or 'provider' not in data or 'intern_id' not in data:
            return jsonify({
                'success': False,
                'message': 'Provider and intern_id are required'
            }), 400
        
        # Get intern data for estimation
        intern_data = _get_intern_data(
            intern_id=data['intern_id'],
            project_id=data.get('project_id'),
            date_range=data.get('date_range', {}),
            supervisor_id=user['id']
        )
        
        if not intern_data:
            return jsonify({
                'success': False,
                'message': 'No data found for cost estimation'
            }), 404
        
        # Get cost estimate
        cost_estimate = ai_manager.estimate_report_cost(data['provider'], intern_data)
        
        return jsonify({
            'success': True,
            'cost_estimate': cost_estimate
        })
        
    except Exception as e:
        logger.error(f"Error estimating report cost: {e}")
        return jsonify({
            'success': False,
            'message': 'Failed to estimate report cost',
            'error': str(e)
        }), 500

@ai_routes.route('/feedback', methods=['POST'])
@token_required
def submit_report_feedback(user):
    """
    Submit feedback for a generated report
    
    Expected JSON payload:
    {
        "report_id": 123,
        "rating": 5,
        "feedback": "Great analysis, very helpful",
        "feedback_type": "positive|negative|suggestion"
    }
    
    Returns:
        JSON response confirming feedback submission
    """
    try:
        data = request.get_json()
        if not data or 'report_id' not in data:
            return jsonify({
                'success': False,
                'message': 'Report ID is required'
            }), 400
        
        report_id = data['report_id']
        rating = data.get('rating')
        feedback = data.get('feedback', '')
        feedback_type = data.get('feedback_type', 'general')
        
        # Validate rating
        if rating is not None and (rating < 1 or rating > 5):
            return jsonify({
                'success': False,
                'message': 'Rating must be between 1 and 5'
            }), 400
        
        # Save feedback to database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO report_feedback (report_id, user_id, rating, feedback, feedback_type, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (report_id, user['id'], rating, feedback, feedback_type, datetime.now()))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Feedback submitted for report {report_id} by user {user['id']}")
        
        return jsonify({
            'success': True,
            'message': 'Feedback submitted successfully'
        })
        
    except Exception as e:
        logger.error(f"Error submitting feedback: {e}")
        return jsonify({
            'success': False,
            'message': 'Failed to submit feedback',
            'error': str(e)
        }), 500

def _get_intern_data(intern_id: int, project_id: int = None, date_range: dict = None, supervisor_id: int = None) -> dict:
    """
    Get intern data for AI report generation
    
    Args:
        intern_id: ID of the intern
        project_id: Optional project ID filter
        date_range: Optional date range filter
        supervisor_id: Optional supervisor ID for authorization
        
    Returns:
        Dictionary containing intern data or None if not found
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Get intern basic information
        intern_query = """
        SELECT 
            u.id, u.name, u.email, u.project_id,
            p.name as project_name, p.description as project_description,
            s.name as supervisor_name
        FROM users u
        LEFT JOIN projects p ON u.project_id = p.id
        LEFT JOIN users s ON p.supervisor_id = s.id
        WHERE u.id = %s AND u.role = 'intern'
        """
        
        params = [intern_id]
        
        # Add supervisor authorization if provided
        if supervisor_id:
            intern_query += " AND p.supervisor_id = %s"
            params.append(supervisor_id)
        
        cursor.execute(intern_query, params)
        intern_info = cursor.fetchone()
        
        if not intern_info:
            cursor.close()
            conn.close()
            return None
        
        # Get logbook entries
        logbook_query = """
        SELECT * FROM logbook_entries 
        WHERE intern_id = %s
        """
        logbook_params = [intern_id]
        
        # Add date range filter if provided
        if date_range:
            if date_range.get('start_date'):
                logbook_query += " AND date >= %s"
                logbook_params.append(date_range['start_date'])
            if date_range.get('end_date'):
                logbook_query += " AND date <= %s"
                logbook_params.append(date_range['end_date'])
        
        logbook_query += " ORDER BY date DESC"
        cursor.execute(logbook_query, logbook_params)
        logbook_entries = cursor.fetchall()
        
        # Get performance metrics if available
        cursor.execute("""
            SELECT * FROM intern_performance_metrics 
            WHERE intern_id = %s
            ORDER BY evaluation_date DESC
            LIMIT 1
        """, (intern_id,))
        performance_metrics = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        # Compile intern data
        intern_data = {
            'intern_id': intern_info['id'],
            'intern_name': intern_info['name'],
            'intern_email': intern_info['email'],
            'project_id': intern_info['project_id'],
            'project_name': intern_info['project_name'],
            'project_description': intern_info['project_description'],
            'supervisor_name': intern_info['supervisor_name'],
            'logbook_entries': logbook_entries,
            'performance_metrics': performance_metrics,
            'period': _format_date_range(date_range) if date_range else 'Recent activity'
        }
        
        return intern_data
        
    except Exception as e:
        logger.error(f"Error getting intern data: {e}")
        return None

def _save_report_to_database(report: dict, generated_by: int, intern_id: int, project_id: int = None) -> int:
    """
    Save generated AI report to database
    
    Args:
        report: Generated report dictionary
        generated_by: ID of user who generated the report
        intern_id: ID of the intern
        project_id: Optional project ID
        
    Returns:
        ID of saved report
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Extract metadata
        metadata = {
            'provider_used': report.get('provider_used'),
            'fallback_used': report.get('fallback_used', False),
            'original_provider': report.get('original_provider'),
            'generation_time': report.get('generation_time'),
            'model_used': report.get('model_used')
        }
        
        cursor.execute("""
            INSERT INTO ai_reports (
                intern_id, project_id, report_type, provider_used,
                content, metadata, generated_by, generated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            intern_id,
            project_id,
            report.get('report_type', 'weekly'),
            report.get('provider_used'),
            json.dumps(report.get('content', {})),
            json.dumps(metadata),
            generated_by,
            datetime.now()
        ))
        
        report_id = cursor.lastrowid
        conn.commit()
        cursor.close()
        conn.close()
        
        return report_id
        
    except Exception as e:
        logger.error(f"Error saving report to database: {e}")
        raise

def _format_date_range(date_range: dict) -> str:
    """
    Format date range for display
    
    Args:
        date_range: Dictionary with start_date and end_date
        
    Returns:
        Formatted date range string
    """
    if not date_range:
        return "Recent activity"
    
    start = date_range.get('start_date', '')
    end = date_range.get('end_date', '')
    
    if start and end:
        return f"{start} to {end}"
    elif start:
        return f"From {start}"
    elif end:
        return f"Until {end}"
    else:
        return "Recent activity"
