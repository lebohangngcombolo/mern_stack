from functools import wraps
from flask import jsonify, request, current_app
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity, get_jwt
from marshmallow import ValidationError
from app.models import User
from app.extensions import limiter

def role_required(required_role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            try:
                verify_jwt_in_request()
                current_user_id = get_jwt_identity()
                user = User.query.get(current_user_id)
                
                if not user:
                    return jsonify({"error": "User not found"}), 404
                
                # Role hierarchy: super_admin > admin > user
                role_hierarchy = {'user': 0, 'admin': 1, 'super_admin': 2}
                user_role_level = role_hierarchy.get(user.role, 0)
                required_role_level = role_hierarchy.get(required_role, 0)
                
                if user_role_level < required_role_level:
                    return jsonify({"error": "Insufficient permissions"}), 403
                
                return f(*args, **kwargs)
            except Exception as e:
                return jsonify({"error": "Authorization failed"}), 401
        return decorated_function
    return decorator

def mfa_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            verify_jwt_in_request()
            claims = get_jwt()
            
            if claims.get('mfa_pending'):
                return jsonify({"error": "MFA verification required"}), 403
                
            return f(*args, **kwargs)
        except Exception as e:
            return jsonify({"error": "MFA verification failed"}), 401
    return decorated_function

def handle_auth_errors(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except ValidationError as e:
            return jsonify({'error': 'Validation error', 'details': e.messages}), 400
        except Exception as e:
            current_app.logger.error(f'Auth error in {f.__name__}: {str(e)}', exc_info=True)
            return jsonify({'error': 'Internal server error'}), 500
    return decorated_function

def rate_limit_by_user(requests_per_minute=10):
    """Rate limit decorator that uses user ID as key when authenticated, fallback to IP"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Try to get user ID from JWT token first
            key_func = lambda: get_jwt_identity() or request.remote_addr
            limited_function = limiter.limit(f"{requests_per_minute} per minute", key_func=key_func)(f)
            return limited_function(*args, **kwargs)
        return decorated_function
    return decorator

def rate_limit_by_email(requests_per_minute=5):
    """Rate limit decorator that uses email from request body as key"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            key_func = lambda: request.json.get('email', 'global') if request.json else 'global'
            limited_function = limiter.limit(f"{requests_per_minute} per minute", key_func=key_func)(f)
            return limited_function(*args, **kwargs)
        return decorated_function
    return decorator

def rate_limit_by_token(requests_per_hour=5):
    """Rate limit decorator that uses token from request body as key"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            key_func = lambda: request.json.get('token', 'global') if request.json else 'global'
            limited_function = limiter.limit(f"{requests_per_hour} per hour", key_func=key_func)(f)
            return limited_function(*args, **kwargs)
        return decorated_function
    return decorator

def rate_limit_by_ip(requests_per_minute=10):
    """Rate limit decorator that uses IP address as key"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            limited_function = limiter.limit(f"{requests_per_minute} per minute")(f)
            return limited_function(*args, **kwargs)
        return decorated_function
    return decorator