from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash
from utils.db import get_db_connection
from utils.email_service import send_otp_email
import random
import string
from datetime import datetime, timedelta

forgot_password_routes = Blueprint('forgot_password_routes', __name__)

# In-memory OTP storage (in production, use Redis or database)
otp_storage = {}

def generate_otp():
    """Generate a 6-digit OTP"""
    return ''.join(random.choices(string.digits, k=6))


@forgot_password_routes.route('/forgot-password/send-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    email = data.get('email')

    if not email:
        return jsonify({'success': False, 'message': 'Email is required'}), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Check if user exists and is admin/supervisor
    cursor.execute("SELECT id, role FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()
    
    cursor.close()
    conn.close()

    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404

    if user['role'] not in ['admin', 'supervisor']:
        return jsonify({'success': False, 'message': 'Password reset is only available for admin/supervisor'}), 403

    # Generate OTP
    otp = generate_otp()
    expiry = datetime.now() + timedelta(minutes=10)  # OTP valid for 10 minutes
    
    # Store OTP
    otp_storage[email] = {
        'otp': otp,
        'expiry': expiry
    }
    
    # Send OTP via email
    email_sent = send_otp_email(email, otp)
    
    if email_sent:
        return jsonify({
            'success': True, 
            'message': 'OTP sent to your email. Please check your inbox.',
            'debug_otp': otp  # Shows OTP in response for testing (remove in production!)
        }), 200
    else:
        return jsonify({
            'success': False, 
            'message': 'Failed to send email. Please contact administrator or check server logs.'
        }), 500


@forgot_password_routes.route('/forgot-password/reset', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email')
    otp = data.get('otp')
    new_password = data.get('new_password')

    if not email or not otp or not new_password:
        return jsonify({'success': False, 'message': 'All fields are required'}), 400

    if len(new_password) < 6:
        return jsonify({'success': False, 'message': 'Password must be at least 6 characters'}), 400

    # Verify OTP
    if email not in otp_storage:
        return jsonify({'success': False, 'message': 'OTP not found. Please request a new one.'}), 404

    stored_data = otp_storage[email]
    
    # Check if OTP has expired
    if datetime.now() > stored_data['expiry']:
        del otp_storage[email]
        return jsonify({'success': False, 'message': 'OTP has expired. Please request a new one.'}), 400

    # Check if OTP matches
    if stored_data['otp'] != otp:
        return jsonify({'success': False, 'message': 'Invalid OTP'}), 400

    # Update password
    conn = get_db_connection()
    cursor = conn.cursor()
    
    password_hash = generate_password_hash(new_password)
    
    try:
        cursor.execute(
            "UPDATE users SET password_hash=%s WHERE email=%s",
            (password_hash, email)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        # Remove OTP from storage
        del otp_storage[email]
        
        return jsonify({
            'success': True, 
            'message': 'Password reset successfully'
        }), 200
        
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'success': False, 'message': f'Error resetting password: {str(e)}'}), 500
