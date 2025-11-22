# app/routes/sso.py
from flask import Blueprint, request, jsonify, current_app, redirect
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token
import jwt
import datetime
from app.models import db, User, CompanyApp
from app.services.audit_service import AuditService

sso_bp = Blueprint('sso', __name__)

@sso_bp.route('/generate-token', methods=['POST'])
@jwt_required()
def generate_sso_token():
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        app_id = data.get('app_id')
        
        if not app_id:
            return jsonify({'error': 'App ID is required'}), 400
        
        app = CompanyApp.query.get(app_id)
        if not app or not app.is_active:
            return jsonify({'error': 'App not found or inactive'}), 404
        
        # Create SSO token
        payload = {
            'user_id': user.id,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'role': user.role,
            'app_id': app_id,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=5),
            'iat': datetime.datetime.utcnow(),
            'iss': 'company-hub'
        }
        
        sso_token = jwt.encode(payload, current_app.config['SSO_JWT_SECRET'], algorithm='HS256')
        
        # Create redirect URL
        redirect_url = f"{app.sso_callback_url}?token={sso_token}"
        
        AuditService.log(user.id, 'sso_token_generated', 'app', app_id, f"Generated token for {app.name}")
        
        return jsonify({
            'sso_token': sso_token,
            'redirect_url': redirect_url
        }), 200
        
    except Exception as e:
        current_app.logger.error(f'SSO token generation error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@sso_bp.route('/validate', methods=['POST'])
def validate_sso_token():
    try:
        data = request.get_json()
        token = data.get('token')
        
        if not token:
            return jsonify({'error': 'Token is required'}), 400
        
        # Verify token
        payload = jwt.decode(
            token, 
            current_app.config['SSO_JWT_SECRET'], 
            algorithms=['HS256'],
            issuer='company-hub'
        )
        
        user_id = payload['user_id']
        app_id = payload['app_id']
        
        # Verify user and app still exist and are active
        user = User.query.get(user_id)
        app = CompanyApp.query.get(app_id)
        
        if not user or not user.is_active or not app or not app.is_active:
            return jsonify({'error': 'Invalid token'}), 401
        
        AuditService.log(user.id, 'sso_token_validated', 'app', app_id, f"Validated token for {app.name}")
        
        return jsonify({
            'valid': True,
            'user': {
                'id': user.id,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'role': user.role
            },
            'app': {
                'id': app.id,
                'name': app.name
            }
        }), 200
        
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'Token has expired'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': 'Invalid token'}), 401
    except Exception as e:
        current_app.logger.error(f'SSO token validation error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

