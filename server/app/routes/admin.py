# app/routes/admin.py
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, User, AuditLog, CompanyApp
from app.services.auth_service import AuthService
from app.services.email_service import EmailService
from app.services.audit_service import AuditService
from app.utils.decorators import role_required
from sqlalchemy import desc

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/dashboard', methods=['GET'])
@jwt_required()
@role_required('admin')
def admin_dashboard():
    try:
        # Get dashboard statistics
        total_users = User.query.count()
        active_users = User.query.filter_by(is_active=True).count()
        recent_users = User.query.order_by(desc(User.created_at)).limit(5).all()
        
        stats = {
            'total_users': total_users,
            'active_users': active_users,
            'recent_users': [user.to_dict() for user in recent_users]
        }
        
        AuditService.log(get_jwt_identity(), 'view_admin_dashboard')
        
        return jsonify(stats), 200
        
    except Exception as e:
        current_app.logger.error(f'Admin dashboard error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@admin_bp.route('/users', methods=['GET'])
@jwt_required()
@role_required('admin')
def get_users():
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 10, type=int)
        search = request.args.get('search', '')
        
        query = User.query
        
        if search:
            query = query.filter(
                db.or_(
                    User.email.ilike(f'%{search}%'),
                    User.first_name.ilike(f'%{search}%'),
                    User.last_name.ilike(f'%{search}%')
                )
            )
        
        users = query.order_by(desc(User.created_at)).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        AuditService.log(get_jwt_identity(), 'view_users_list')
        
        return jsonify({
            'users': [user.to_dict() for user in users.items],
            'total': users.total,
            'pages': users.pages,
            'current_page': page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f'Get users error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@admin_bp.route('/users/enroll', methods=['POST'])
@jwt_required()
@role_required('admin')
def enroll_user():
    try:
        data = request.get_json()
        email = data.get('email')
        first_name = data.get('first_name')
        last_name = data.get('last_name')
        role = data.get('role', 'user')
        
        if not all([email, first_name, last_name]):
            return jsonify({'error': 'Email, first name, and last name are required'}), 400
        
        if role not in ['user', 'admin']:
            return jsonify({'error': 'Invalid role'}), 400
        
        email = email.strip().lower()
        
        # Check if user already exists
        existing_user = User.query.filter_by(email=email).first()
        if existing_user:
            return jsonify({'error': 'User with this email already exists'}), 409
        
        # Generate temporary password
        temp_password = AuthService.generate_temporary_password()
        
        # Create user
        user = User(
            email=email,
            first_name=first_name,
            last_name=last_name,
            role=role,
            is_verified=True
        )
        user.set_password(temp_password)
        
        db.session.add(user)
        db.session.commit()
        
        # Send welcome email with temporary password
        EmailService.send_temporary_password(email, temp_password, first_name)
        
        AuditService.log(
            get_jwt_identity(), 
            'user_enrolled', 
            'user', 
            user.id, 
            f"Enrolled user {email} with role {role}"
        )
        
        return jsonify({
            'message': 'User enrolled successfully',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f'User enrollment error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@admin_bp.route('/users/<int:user_id>', methods=['PUT'])
@jwt_required()
@role_required('admin')
def update_user(user_id):
    try:
        data = request.get_json()
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Update allowed fields
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        if 'role' in data and data['role'] in ['user', 'admin']:
            user.role = data['role']
        if 'is_active' in data:
            user.is_active = data['is_active']
        
        db.session.commit()
        
        AuditService.log(
            get_jwt_identity(), 
            'user_updated', 
            'user', 
            user.id, 
            f"Updated user {user.email}"
        )
        
        return jsonify({
            'message': 'User updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f'User update error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@admin_bp.route('/audit-logs', methods=['GET'])
@jwt_required()
@role_required('admin')
def get_audit_logs():
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        user_id = request.args.get('user_id', type=int)
        action = request.args.get('action', '')
        
        query = AuditLog.query
        
        if user_id:
            query = query.filter_by(user_id=user_id)
        if action:
            query = query.filter(AuditLog.action.ilike(f'%{action}%'))
        
        logs = query.order_by(desc(AuditLog.timestamp)).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        AuditService.log(get_jwt_identity(), 'view_audit_logs')
        
        return jsonify({
            'logs': [{
                'id': log.id,
                'user_id': log.user_id,
                'action': log.action,
                'resource': log.resource,
                'resource_id': log.resource_id,
                'ip_address': log.ip_address,
                'timestamp': log.timestamp.isoformat(),
                'details': log.details
            } for log in logs.items],
            'total': logs.total,
            'pages': logs.pages,
            'current_page': page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f'Get audit logs error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@admin_bp.route('/apps', methods=['GET'])
@jwt_required()
def get_company_apps():
    try:
        # Fetch only active apps
        apps = CompanyApp.query.filter_by(is_active=True).all()

        # You can optionally filter apps for regular users here
        # For now, we return all active apps to everyone

        return jsonify({
            'apps': [{
                'id': app.id,
                'name': app.name,
                'description': app.description,
                'app_url': app.app_url
            } for app in apps]
        }), 200

    except Exception as e:
        current_app.logger.error(f'Get company apps error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500
