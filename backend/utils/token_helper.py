import jwt
import datetime
from flask import request, jsonify

SECRET_KEY = "your_secret_key_here"

# Generate JWT token
def generate_token(user_id, role):
    payload = {
        'user_id': user_id,
        'role': role,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7)  # valid 7 days
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
    return token

# Decode JWT token
def decode_token(token):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

# Decorator for protected routes
from functools import wraps

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(" ")[1]  # Bearer <token>

        if not token:
            return jsonify({'message': 'Token is missing!'}), 401

        data = decode_token(token)
        if not data:
            return jsonify({'message': 'Token is invalid or expired!'}), 401

        # pass user info to route
        return f(user=data, *args, **kwargs)
    return decorated
