from flask import Blueprint, request, jsonify
from utils.db import get_db_connection
from utils.token_helper import token_required
from datetime import datetime, date

intern_routes = Blueprint('intern_routes', __name__)

# Get logbook entries (with optional date filter)
@intern_routes.route('/intern/logbook', methods=['GET'])
@token_required
def get_logbook(user):
    if user['role'] != 'intern':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403
    
    date_filter = request.args.get('date')  # Optional date filter (YYYY-MM-DD)
    
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    if date_filter:
        cursor.execute(
            "SELECT * FROM logbook_entries WHERE intern_id=%s AND date=%s ORDER BY date DESC",
            (user['user_id'], date_filter)
        )
    else:
        cursor.execute(
            "SELECT * FROM logbook_entries WHERE intern_id=%s ORDER BY date DESC",
            (user['user_id'],)
        )
    
    logs = cursor.fetchall()
    
    # Convert date objects to strings for JSON serialization
    for log in logs:
        if isinstance(log.get('date'), date):
            log['date'] = log['date'].strftime('%Y-%m-%d')
    
    cursor.close()
    conn.close()
    
    return jsonify({'success': True, 'logs': logs})

# Create logbook entry
@intern_routes.route('/intern/logbook', methods=['POST'])
@token_required
def create_logbook(user):
    if user['role'] != 'intern':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    data = request.get_json()
    
    # Check if entry already exists for today
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    cursor.execute(
        "SELECT id FROM logbook_entries WHERE intern_id=%s AND date=CURDATE()",
        (user['user_id'],)
    )
    existing = cursor.fetchone()
    
    if existing:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': 'You have already submitted today\'s log'}), 400
    
    # Insert new entry
    cursor.execute(
        """
        INSERT INTO logbook_entries (intern_id, date, status, task_stack, todays_work, challenges, tomorrow_plan)
        VALUES (%s, CURDATE(), %s, %s, %s, %s, %s)
        """,
        (user['user_id'], data['status'], data['task_stack'], data['todays_work'], data.get('challenges'), data.get('tomorrow_plan'))
    )
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({'success': True, 'message': 'Logbook submitted!'})
