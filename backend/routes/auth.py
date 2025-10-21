from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from utils.db import get_db_connection
from utils.token_helper import generate_token

auth_routes = Blueprint('auth_routes', __name__)

# ===================== SIGNUP =====================
@auth_routes.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    name = data.get('name')
    email = data.get('email')
    password = data.get('password')

    if not name or not email or not password:
        return jsonify({'success': False, 'message': 'All fields are required'}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    # Check if user exists
    cursor.execute("SELECT id FROM users WHERE email=%s", (email,))
    if cursor.fetchone():
        return jsonify({'success': False, 'message': 'Email already exists'}), 409

    password_hash = generate_password_hash(password)
    cursor.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
        (name, email, password_hash)
    )
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({'success': True, 'message': 'User registered successfully'}), 201

# ===================== LOGIN =====================
@auth_routes.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()

    if not user or not check_password_hash(user['password_hash'], password):
        return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

    token = generate_token(user['id'], user['role'])
    cursor.close()
    conn.close()

    return jsonify({'success': True, 'token': token, 'user': {'id': user['id'], 'name': user['name'], 'role': user['role']}})


# ===================== LOGIN BY EMAIL (NO PASSWORD) =====================
@auth_routes.route('/login-by-email', methods=['POST'])
def login_by_email():
    data = request.get_json()
    email = data.get('email')
    role = data.get('role')

    if not email or not role:
        return jsonify({'success': False, 'message': 'Email and role are required'}), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()

    if not user:
        return jsonify({'success': False, 'message': 'User not found. Contact admin to register.'}), 404

    # Verify role matches
    if user['role'] != role:
        return jsonify({'success': False, 'message': f'Invalid role. This user is registered as {user["role"]}.'}), 403

    token = generate_token(user['id'], user['role'])
    cursor.close()
    conn.close()

    return jsonify({
        'success': True, 
        'token': token, 
        'user': {
            'id': user['id'], 
            'name': user['name'], 
            'role': user['role'],
            'slt_id': user.get('slt_id'),
            'project_id': user.get('project_id')
        }
    })
