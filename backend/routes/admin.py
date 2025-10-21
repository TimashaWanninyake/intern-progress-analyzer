from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash
from utils.db import get_db_connection
from utils.token_helper import decode_token

admin_routes = Blueprint('admin_routes', __name__)

# Decorator to verify admin access
def admin_required(f):
    from functools import wraps
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'success': False, 'message': 'Token required'}), 401
        
        token = token.replace('Bearer ', '')
        payload = decode_token(token)
        
        if not payload or payload.get('role') != 'admin':
            return jsonify({'success': False, 'message': 'Admin access required'}), 403
        
        return f(*args, **kwargs)
    return decorated_function


# ===================== CREATE SUPERVISOR WITH PASSWORD =====================
@admin_routes.route('/admin/create-supervisor', methods=['POST'])
@admin_required
def create_supervisor():
    data = request.get_json()
    slt_id = data.get('slt_id')
    name = data.get('name')
    email = data.get('email')
    password = data.get('password')

    if not name or not email or not password:
        return jsonify({'success': False, 'message': 'Name, email, and password are required'}), 400

    if len(password) < 6:
        return jsonify({'success': False, 'message': 'Password must be at least 6 characters'}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    # Check if email already exists
    cursor.execute("SELECT id FROM users WHERE email=%s", (email,))
    if cursor.fetchone():
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': 'Email already registered'}), 409

    # Hash the password
    password_hash = generate_password_hash(password)

    try:
        cursor.execute(
            """INSERT INTO users (slt_id, name, email, password_hash, role) 
               VALUES (%s, %s, %s, %s, %s)""",
            (slt_id, name, email, password_hash, 'supervisor')
        )
        conn.commit()
        user_id = cursor.lastrowid
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True, 
            'message': 'Supervisor account created successfully',
            'user': {
                'id': user_id,
                'slt_id': slt_id,
                'name': name,
                'email': email,
                'role': 'supervisor'
            }
        }), 201
        
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': f'Error creating supervisor: {str(e)}'}), 500


# ===================== ADD USER (INTERN/SUPERVISOR) =====================
@admin_routes.route('/admin/add-user', methods=['POST'])
@admin_required
def add_user():
    data = request.get_json()
    slt_id = data.get('slt_id')
    name = data.get('name')
    email = data.get('email')
    role = data.get('role')  # 'intern' or 'supervisor'
    project_id = data.get('project_id')

    if not name or not email or not role:
        return jsonify({'success': False, 'message': 'Name, email, and role are required'}), 400

    if role not in ['intern', 'supervisor']:
        return jsonify({'success': False, 'message': 'Role must be intern or supervisor'}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    # Check if email already exists
    cursor.execute("SELECT id FROM users WHERE email=%s", (email,))
    if cursor.fetchone():
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': 'Email already registered'}), 409

    # Generate a default password hash (can be null or empty since we use email-only login)
    default_password_hash = generate_password_hash('temporary_password')

    try:
        cursor.execute(
            """INSERT INTO users (slt_id, name, email, password_hash, role, project_id) 
               VALUES (%s, %s, %s, %s, %s, %s)""",
            (slt_id, name, email, default_password_hash, role, project_id)
        )
        conn.commit()
        user_id = cursor.lastrowid
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True, 
            'message': f'{role.capitalize()} added successfully',
            'user': {
                'id': user_id,
                'slt_id': slt_id,
                'name': name,
                'email': email,
                'role': role,
                'project_id': project_id
            }
        }), 201
        
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': f'Error adding user: {str(e)}'}), 500


# ===================== GET ALL USERS =====================
@admin_routes.route('/admin/users', methods=['GET'])
@admin_required
def get_all_users():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        cursor.execute("""
            SELECT id, slt_id, name, email, role, project_id, created_at 
            FROM users 
            ORDER BY created_at DESC
        """)
        users = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'users': users})
        
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': f'Error fetching users: {str(e)}'}), 500


# ===================== UPDATE USER =====================
@admin_routes.route('/admin/user/<int:user_id>', methods=['PUT'])
@admin_required
def update_user(user_id):
    data = request.get_json()
    slt_id = data.get('slt_id')
    name = data.get('name')
    email = data.get('email')
    role = data.get('role')
    project_id = data.get('project_id')

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # Check if user exists
        cursor.execute("SELECT id FROM users WHERE id=%s", (user_id,))
        if not cursor.fetchone():
            cursor.close()
            conn.close()
            return jsonify({'success': False, 'message': 'User not found'}), 404

        cursor.execute("""
            UPDATE users 
            SET slt_id=%s, name=%s, email=%s, role=%s, project_id=%s 
            WHERE id=%s
        """, (slt_id, name, email, role, project_id, user_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'User updated successfully'})
        
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': f'Error updating user: {str(e)}'}), 500


# ===================== DELETE USER =====================
@admin_routes.route('/admin/user/<int:user_id>', methods=['DELETE'])
@admin_required
def delete_user(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # Check if user exists
        cursor.execute("SELECT id FROM users WHERE id=%s", (user_id,))
        if not cursor.fetchone():
            cursor.close()
            conn.close()
            return jsonify({'success': False, 'message': 'User not found'}), 404

        cursor.execute("DELETE FROM users WHERE id=%s", (user_id,))
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'User deleted successfully'})
        
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': f'Error deleting user: {str(e)}'}), 500
