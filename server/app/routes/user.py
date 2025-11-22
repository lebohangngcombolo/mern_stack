# app/routes/user.py
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import db, User, UserOnboarding, CompanyApp
from app.services.audit_service import AuditService

user_bp = Blueprint('user', __name__)

@user_bp.route('/dashboard', methods=['GET'])
@jwt_required()
def user_dashboard():
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Get available apps for SSO
        apps = CompanyApp.query.filter_by(is_active=True).all()
        
        dashboard_data = {
            'user': user.to_dict(),
            'apps': [{
                'id': app.id,
                'name': app.name,
                'description': app.description,
                'app_url': app.app_url
            } for app in apps]
        }
        
        AuditService.log(user.id, 'view_user_dashboard')
        
        return jsonify(dashboard_data), 200
        
    except Exception as e:
        current_app.logger.error(f'User dashboard error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@user_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({'user': user.to_dict()}), 200
        
    except Exception as e:
        current_app.logger.error(f'Get profile error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@user_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        
        db.session.commit()
        
        AuditService.log(user.id, 'profile_updated')
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f'Update profile error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@user_bp.route('/onboarding', methods=['POST'])
@jwt_required()
def save_onboarding():
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        step = data.get('step', 0)
        profile_data = data.get('profile_data', {})
        
        onboarding = UserOnboarding.query.filter_by(user_id=user.id).first()
        if not onboarding:
            onboarding = UserOnboarding(user_id=user.id)
            db.session.add(onboarding)
        
        onboarding.step_completed = step
        onboarding.profile_data = profile_data
        
        # Mark onboarding as completed if final step
        if step >= 3:  # Assuming 3 is the final step
            user.onboarding_completed = True
            onboarding.completed_at = db.func.now()
        
        db.session.commit()
        
        AuditService.log(user.id, 'onboarding_progress', details=f"Completed step {step}")
        
        return jsonify({
            'message': 'Onboarding progress saved',
            'onboarding_completed': user.onboarding_completed
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f'Onboarding save error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500

@user_bp.route('/onboarding', methods=['GET'])
@jwt_required()
def get_onboarding():
    try:
        current_user_id = get_jwt_identity()
        onboarding = UserOnboarding.query.filter_by(user_id=current_user_id).first()
        
        if not onboarding:
            return jsonify({
                'step_completed': 0,
                'profile_data': {},
                'completed': False
            }), 200
        
        return jsonify({
            'step_completed': onboarding.step_completed,
            'profile_data': onboarding.profile_data or {},
            'completed': onboarding.completed_at is not None
        }), 200
        
    except Exception as e:
        current_app.logger.error(f'Get onboarding error: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500