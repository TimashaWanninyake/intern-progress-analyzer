from flask import Blueprint, request, jsonify
from utils.db import get_db_connection
from utils.token_helper import token_required
from datetime import datetime

project_routes = Blueprint('project_routes', __name__)

# Get all projects with detailed information
@project_routes.route('/projects', methods=['GET'])
@token_required
def get_projects(user):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Get projects with supervisor info and intern count
        query = """
            SELECT 
                p.*,
                u.name as supervisor_name,
                u.email as supervisor_email,
                (SELECT COUNT(DISTINCT pa.intern_id) 
                 FROM project_assignments pa 
                 WHERE pa.project_id = p.id AND pa.is_active = TRUE) as intern_count
            FROM projects p
            LEFT JOIN users u ON p.supervisor_id = u.id
            ORDER BY 
                FIELD(p.status, 'Ongoing', 'Hold', 'Completed'),
                p.created_at DESC
        """
        cursor.execute(query)
        projects = cursor.fetchall()
        
        # Convert date objects to strings for JSON serialization
        for project in projects:
            if project.get('start_date'):
                project['start_date'] = project['start_date'].strftime('%Y-%m-%d')
            if project.get('end_date'):
                project['end_date'] = project['end_date'].strftime('%Y-%m-%d')
            if project.get('created_at'):
                project['created_at'] = project['created_at'].strftime('%Y-%m-%d %H:%M:%S')
            if project.get('updated_at'):
                project['updated_at'] = project['updated_at'].strftime('%Y-%m-%d %H:%M:%S')
        
        cursor.close()
        conn.close()
        return jsonify({'success': True, 'projects': projects})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Get detailed information about a specific project
@project_routes.route('/projects/<int:project_id>', methods=['GET'])
@token_required
def get_project_details(user, project_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Get project details
        cursor.execute("""
            SELECT 
                p.*,
                u.name as supervisor_name,
                u.email as supervisor_email,
                u.slt_id as supervisor_slt_id
            FROM projects p
            LEFT JOIN users u ON p.supervisor_id = u.id
            WHERE p.id = %s
        """, (project_id,))
        project = cursor.fetchone()
        
        if not project:
            cursor.close()
            conn.close()
            return jsonify({'success': False, 'message': 'Project not found'}), 404
        
        # Get assigned interns
        cursor.execute("""
            SELECT 
                u.id,
                u.slt_id,
                u.name,
                u.email,
                pa.role_in_project,
                pa.assigned_date,
                pa.is_active
            FROM project_assignments pa
            JOIN users u ON pa.intern_id = u.id
            WHERE pa.project_id = %s AND pa.is_active = TRUE
            ORDER BY u.name
        """, (project_id,))
        interns = cursor.fetchall()
        
        # Convert dates to strings
        if project.get('start_date'):
            project['start_date'] = project['start_date'].strftime('%Y-%m-%d')
        if project.get('end_date'):
            project['end_date'] = project['end_date'].strftime('%Y-%m-%d')
        if project.get('created_at'):
            project['created_at'] = project['created_at'].strftime('%Y-%m-%d %H:%M:%S')
        if project.get('updated_at'):
            project['updated_at'] = project['updated_at'].strftime('%Y-%m-%d %H:%M:%S')
        
        for intern in interns:
            if intern.get('assigned_date'):
                intern['assigned_date'] = intern['assigned_date'].strftime('%Y-%m-%d')
        
        project['assigned_interns'] = interns
        project['intern_count'] = len(interns)
        
        cursor.close()
        conn.close()
        return jsonify({'success': True, 'project': project})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Update project status
@project_routes.route('/projects/<int:project_id>/status', methods=['PUT'])
@token_required
def update_project_status(user, project_id):
    if user['role'] not in ['admin', 'supervisor']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403
    
    try:
        data = request.get_json()
        new_status = data.get('status')
        
        if new_status not in ['Ongoing', 'Completed', 'Hold']:
            return jsonify({'success': False, 'message': 'Invalid status'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Update status and end_date if completing
        if new_status == 'Completed':
            cursor.execute("""
                UPDATE projects 
                SET status = %s, end_date = CURDATE()
                WHERE id = %s
            """, (new_status, project_id))
            
            # Auto-unassign interns from completed project (set is_active = FALSE)
            cursor.execute("""
                UPDATE project_assignments 
                SET is_active = FALSE 
                WHERE project_id = %s AND is_active = TRUE
            """, (project_id,))
            
        elif new_status == 'Ongoing':
            # When reopening, clear end_date
            cursor.execute("""
                UPDATE projects 
                SET status = %s, end_date = NULL
                WHERE id = %s
            """, (new_status, project_id))
        else:
            cursor.execute("""
                UPDATE projects 
                SET status = %s
                WHERE id = %s
            """, (new_status, project_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': f'Project status updated to {new_status}'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Add new project
@project_routes.route('/projects', methods=['POST'])
@token_required
def add_project(user):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    try:
        data = request.get_json()
        name = data.get('name')
        description = data.get('description', '')
        project_type = data.get('project_type', 'Development')
        technologies = data.get('technologies', '')
        
        if not name:
            return jsonify({'success': False, 'message': 'Project name is required'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO projects (name, description, project_type, technologies, supervisor_id, status)
            VALUES (%s, %s, %s, %s, %s, 'Ongoing')
        """, (name, description, project_type, technologies, user['user_id']))
        
        project_id = cursor.lastrowid
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Project created successfully', 'project_id': project_id})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Update project details
@project_routes.route('/projects/<int:project_id>', methods=['PUT'])
@token_required
def update_project(user, project_id):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    try:
        data = request.get_json()
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Update project details
        cursor.execute("""
            UPDATE projects 
            SET name = %s, description = %s, project_type = %s, technologies = %s
            WHERE id = %s
        """, (
            data.get('name'),
            data.get('description'),
            data.get('project_type', 'Development'),
            data.get('technologies', ''),
            project_id
        ))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Project updated successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Change project supervisor
@project_routes.route('/projects/<int:project_id>/supervisor', methods=['PUT'])
@token_required
def change_project_supervisor(user, project_id):
    if user['role'] not in ['supervisor', 'admin']:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 403

    try:
        data = request.get_json()
        new_supervisor_id = data.get('supervisor_id')
        
        if not new_supervisor_id:
            return jsonify({'success': False, 'message': 'Supervisor ID is required'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Verify the new supervisor exists and is a supervisor/admin
        cursor.execute("""
            SELECT id, name FROM users 
            WHERE id = %s AND role IN ('supervisor', 'admin')
        """, (new_supervisor_id,))
        supervisor = cursor.fetchone()
        
        if not supervisor:
            return jsonify({'success': False, 'message': 'Invalid supervisor selected'}), 400
        
        # Update project supervisor
        cursor.execute("""
            UPDATE projects 
            SET supervisor_id = %s, updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (new_supervisor_id, project_id))
        
        if cursor.rowcount == 0:
            return jsonify({'success': False, 'message': 'Project not found'}), 404
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': f'Project supervisor changed to {supervisor[1]}'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@project_routes.route('/projects/<int:project_id>/interns/<int:intern_id>', methods=['DELETE'])
@token_required
def remove_intern_from_project(user, project_id, intern_id):
    """Remove an intern from a project"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if the project exists and belongs to the supervisor
        cursor.execute("""
            SELECT id FROM projects 
            WHERE id = %s AND supervisor_id = %s
        """, (project_id, user['user_id']))
        
        if not cursor.fetchone():
            return jsonify({'success': False, 'message': 'Project not found or unauthorized'}), 404
        
        # Check if the intern is assigned to this project
        cursor.execute("""
            SELECT id FROM project_assignments 
            WHERE project_id = %s AND intern_id = %s AND is_active = 1
        """, (project_id, intern_id))
        
        if not cursor.fetchone():
            return jsonify({'success': False, 'message': 'Intern is not assigned to this project'}), 404
        
        # Remove the intern from the project (set is_active to 0)
        cursor.execute("""
            UPDATE project_assignments 
            SET is_active = 0, removed_date = NOW()
            WHERE project_id = %s AND intern_id = %s AND is_active = 1
        """, (project_id, intern_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Intern removed from project successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
