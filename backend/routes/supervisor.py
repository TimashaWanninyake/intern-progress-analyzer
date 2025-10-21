from flask import Blueprint, jsonify, request
from utils.db import get_db_connection
from utils.token_helper import token_required

supervisor_routes = Blueprint('supervisor_routes', __name__)

# View all interns with their project assignments
@supervisor_routes.route('/supervisor/interns', methods=['GET'])
@token_required
def get_interns(user):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Get interns with their assigned projects
        cursor.execute("""
            SELECT 
                u.id, 
                u.slt_id, 
                u.name, 
                u.email,
                GROUP_CONCAT(
                    CONCAT(p.name, ' (', p.status, ')')
                    ORDER BY p.name SEPARATOR ', '
                ) as assigned_projects,
                COUNT(DISTINCT pa.project_id) as project_count
            FROM users u
            LEFT JOIN project_assignments pa ON u.id = pa.intern_id AND pa.is_active = TRUE
            LEFT JOIN projects p ON pa.project_id = p.id
            WHERE u.role='intern'
            GROUP BY u.id, u.slt_id, u.name, u.email
            ORDER BY u.name
        """)
        interns = cursor.fetchall()
        cursor.close()
        conn.close()

        return jsonify({'success': True, 'interns': interns})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Assign project to intern (supports multiple projects)
@supervisor_routes.route('/supervisor/assign-project', methods=['POST'])
@token_required
def assign_project(user):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    data = request.get_json()
    intern_id = data.get('intern_id')
    project_id = data.get('project_id')
    role_in_project = data.get('role_in_project', 'Developer')

    if intern_id is None or project_id is None:
        return jsonify({'success': False, 'message': 'Intern ID and Project ID are required'}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if assignment already exists
        cursor.execute("""
            SELECT id FROM project_assignments 
            WHERE intern_id=%s AND project_id=%s
        """, (intern_id, project_id))
        
        existing = cursor.fetchone()
        
        if existing:
            # Reactivate if exists
            cursor.execute("""
                UPDATE project_assignments 
                SET is_active=TRUE, role_in_project=%s 
                WHERE intern_id=%s AND project_id=%s
            """, (role_in_project, intern_id, project_id))
            message = 'Project assignment updated'
        else:
            # Create new assignment
            cursor.execute("""
                INSERT INTO project_assignments (intern_id, project_id, role_in_project, is_active)
                VALUES (%s, %s, %s, TRUE)
            """, (intern_id, project_id, role_in_project))
            message = 'Project assigned successfully'
        
        # Also update the old project_id field for backward compatibility (set to latest project)
        cursor.execute("""
            UPDATE users SET project_id=%s WHERE id=%s AND role='intern'
        """, (project_id, intern_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': message}), 200
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# Remove intern from project
@supervisor_routes.route('/supervisor/remove-from-project', methods=['POST'])
@token_required
def remove_from_project(user):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    data = request.get_json()
    intern_id = data.get('intern_id')
    project_id = data.get('project_id')

    if intern_id is None or project_id is None:
        return jsonify({'success': False, 'message': 'Intern ID and Project ID are required'}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE project_assignments 
            SET is_active=FALSE 
            WHERE intern_id=%s AND project_id=%s
        """, (intern_id, project_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Intern removed from project'}), 200
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# Get detailed intern information with projects
@supervisor_routes.route('/supervisor/intern/<int:intern_id>', methods=['GET'])
@token_required
def get_intern_details(user, intern_id):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Get intern basic info
        cursor.execute("""
            SELECT id, slt_id, name, email, created_at
            FROM users 
            WHERE id = %s AND role = 'intern'
        """, (intern_id,))
        intern = cursor.fetchone()
        
        if not intern:
            return jsonify({'success': False, 'message': 'Intern not found'}), 404
            
        # Get intern's projects with supervisor details
        cursor.execute("""
            SELECT 
                p.id, p.name, p.description, p.status, p.project_type, p.technologies,
                p.start_date, p.end_date,
                pa.role_in_project, pa.assigned_date, pa.is_active,
                u.name as supervisor_name, u.email as supervisor_email, u.id as supervisor_id
            FROM project_assignments pa
            JOIN projects p ON pa.project_id = p.id
            JOIN users u ON p.supervisor_id = u.id
            WHERE pa.intern_id = %s
            ORDER BY pa.assigned_date DESC
        """, (intern_id,))
        projects = cursor.fetchall()
        
        # Convert dates to strings for JSON serialization
        for project in projects:
            if project.get('start_date'):
                project['start_date'] = project['start_date'].strftime('%Y-%m-%d')
            if project.get('end_date'):
                project['end_date'] = project['end_date'].strftime('%Y-%m-%d')
            if project.get('assigned_date'):
                project['assigned_date'] = project['assigned_date'].strftime('%Y-%m-%d')
                
        if intern.get('created_at'):
            intern['created_at'] = intern['created_at'].strftime('%Y-%m-%d %H:%M:%S')
            
        intern['projects'] = projects
        
        cursor.close()
        conn.close()

        return jsonify({'success': True, 'intern': intern})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Get all supervisors (for supervisor change functionality)
@supervisor_routes.route('/supervisors', methods=['GET'])
@token_required
def get_supervisors(user):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT id, slt_id, name, email
            FROM users 
            WHERE role IN ('supervisor', 'admin')
            ORDER BY name
        """)
        supervisors = cursor.fetchall()
        
        cursor.close()
        conn.close()

        return jsonify({'success': True, 'supervisors': supervisors})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# View weekly reports
@supervisor_routes.route('/reports', methods=['GET'])
@token_required
def get_reports(user):
    if user['role'] != 'supervisor':
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM weekly_reports ORDER BY week_start_date DESC")
    reports = cursor.fetchall()
    cursor.close()
    conn.close()

    return jsonify({'success': True, 'reports': reports})
