from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import (
    create_access_token, create_refresh_token, jwt_required,
    get_jwt_identity, unset_jwt_cookies, get_jwt
)
from app.models import db, User, PasswordReset
from app.services.auth_service import AuthService
from app.services.mfa_service import MFAService
from app.services.email_service import EmailService
from app.services.audit_service import AuditService
from app.schemas.auth_schemas import (
    LoginSchema, MFASchema, ChangePasswordSchema, 
    ForgotPasswordSchema, ResetPasswordSchema,
    SetupMFASchema, VerifyMFASetupSchema
)
from app.utils.decorators import (
    handle_auth_errors, rate_limit_by_email, rate_limit_by_user, 
    rate_limit_by_token, rate_limit_by_ip, mfa_required, handle_auth_errors
)
from app.utils.validators import validate_password_strength
from datetime import datetime, timedelta
from app.extensions import limiter

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['POST'])
@rate_limit_by_email(5)  # 5 attempts per minute per email
@handle_auth_errors
def login():
    schema = LoginSchema()
    data = schema.load(request.get_json(silent=True) or {})
    
    email = data['email'].strip().lower()
    password = data['password']

    user = User.query.filter_by(email=email, is_active=True).first()

    if not user or not user.check_password(password):
        AuditService.log(
            None,
            'login_failed',
            details=f"Failed login attempt for {email}"
        )
        return jsonify({'error': 'Invalid credentials'}), 401

    # Check if account is locked
    if user.is_account_locked():
        lock_time = user.get_account_lock_time()
        return jsonify({
            'error': f'Account temporarily locked. Try again in {lock_time} minutes'
        }), 423

    # MFA flow
    if user.mfa_enabled:
        mfa_session_token = create_access_token(
            identity=str(user.id),
            expires_delta=timedelta(minutes=5),
            additional_claims={
                "mfa_pending": True,
                "auth_context": "password_valid"
            }
        )

        AuditService.log(
            user.id,
            'login_mfa_required',
            details="Password correct - awaiting OTP verification"
        )

        return jsonify({
            'message': 'MFA verification required',
            'mfa_required': True,
            'mfa_session_token': mfa_session_token,
            'user_id': user.id
        }), 200

    # First login flow
    if user.first_login:
        first_login_token = create_access_token(
            identity=str(user.id),
            expires_delta=timedelta(minutes=30),
            additional_claims={"first_login": True}
        )

        AuditService.log(
            user.id,
            'first_login_required',
            details="User must update password before continuing"
        )

        return jsonify({
            'message': 'First login - password change required',
            'first_login': True,
            'first_login_token': first_login_token,
            'user_id': user.id
        }), 200

    # Regular login success
    additional_claims = {"role": user.role}
    access_token = create_access_token(
        identity=str(user.id),
        additional_claims=additional_claims
    )
    refresh_token = create_refresh_token(
        identity=str(user.id),
        additional_claims=additional_claims
    )

    user.last_login = datetime.utcnow()
    db.session.commit()

    AuditService.log(user.id, 'login_success')

    return jsonify({
        'access_token': access_token,
        'refresh_token': refresh_token,
        'user': user.to_dict(),
        'onboarding_required': not user.onboarding_completed
    }), 200

@auth_bp.route('/verify-mfa', methods=['POST'])
@jwt_required()
@rate_limit_by_user(10)  # 10 attempts per minute per user
@handle_auth_errors
def verify_mfa():
    claims = get_jwt()
    current_user_id = get_jwt_identity()

    if not claims.get("mfa_pending"):
        current_app.logger.warning(
            f"MFA verification attempted without mfa_pending claim. User ID: {current_user_id}"
        )
        return jsonify({
            "error": "MFA verification not required",
            "details": "This token is not an MFA session token. Please login again."
        }), 400

    schema = MFASchema()
    data = schema.load(request.get_json(silent=True) or {})
    mfa_code = data['mfa_code']

    user = User.query.get(current_user_id)
    if not user or not user.mfa_secret:
        return jsonify({"error": "MFA not configured"}), 400

    if not MFAService.verify_totp(user.mfa_secret, mfa_code):
        AuditService.log(user.id, "mfa_verification_failed")
        return jsonify({"error": "Invalid MFA code"}), 401

    additional_claims = {"role": user.role}
    access_token = create_access_token(
        identity=str(user.id),
        additional_claims=additional_claims
    )
    refresh_token = create_refresh_token(
        identity=str(user.id),
        additional_claims=additional_claims
    )

    user.last_login = datetime.utcnow()
    db.session.commit()

    AuditService.log(user.id, "mfa_verification_success")

    return jsonify({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user": user.to_dict(),
        "onboarding_required": not user.onboarding_completed
    }), 200

@auth_bp.route('/setup-mfa', methods=['POST'])
@jwt_required()
@rate_limit_by_user(10)  # 10 attempts per minute per user
@handle_auth_errors
def setup_mfa():
    schema = SetupMFASchema()
    schema.load(request.get_json(silent=True) or {})
    
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)

    if not user:
        return jsonify({"error": "User not found"}), 404
    
    if user.mfa_enabled:
        return jsonify({"error": "MFA already enabled"}), 400

    mfa_secret = MFAService.generate_mfa_secret()
    provisioning_uri = MFAService.generate_provisioning_uri(
        user.email,
        mfa_secret,
        current_app.config["MFA_ISSUER"]
    )
    qr_code = MFAService.generate_qr_code(provisioning_uri)

    user.mfa_secret = mfa_secret
    db.session.commit()

    AuditService.log(user.id, "mfa_setup_initiated")

    return jsonify({
        "mfa_secret": mfa_secret,
        "provisioning_uri": provisioning_uri,
        "qr_code": qr_code
    }), 200

@auth_bp.route('/verify-mfa-setup', methods=['POST'])
@jwt_required()
@rate_limit_by_user(10)  # 10 attempts per minute per user
@handle_auth_errors
def verify_mfa_setup():
    schema = VerifyMFASetupSchema()
    data = schema.load(request.get_json(silent=True) or {})
    mfa_code = data['mfa_code']

    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)

    if not user or not user.mfa_secret:
        return jsonify({"error": "MFA setup not initiated"}), 400

    if not MFAService.verify_totp(user.mfa_secret, mfa_code):
        user.mfa_secret = None
        db.session.commit()
        AuditService.log(user.id, "mfa_setup_failed")
        return jsonify({"error": "Invalid MFA code"}), 401

    user.mfa_enabled = True
    db.session.commit()

    AuditService.log(user.id, "mfa_setup_completed")

    return jsonify({
        "message": "MFA setup completed successfully",
        "user": user.to_dict(),
        "onboarding_required": not user.onboarding_completed
    }), 200

@auth_bp.route('/change-password', methods=['POST'])
@jwt_required()
@rate_limit_by_user(5)  # 5 attempts per minute per user
@handle_auth_errors
def change_password():
    schema = ChangePasswordSchema()
    data = schema.load(request.get_json(silent=True) or {})
    current_password = data['current_password']
    new_password = data['new_password']
    
    is_strong, message = validate_password_strength(new_password)
    if not is_strong:
        return jsonify({'error': message}), 400

    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    if not user.check_password(current_password):
        AuditService.log(user.id, 'password_change_failed', details='Incorrect current password')
        return jsonify({'error': 'Current password is incorrect'}), 401
    
    user.set_password(new_password)
    user.first_login = False
    db.session.commit()
    
    AuditService.log(user.id, 'password_changed')
    
    return jsonify({'message': 'Password changed successfully'}), 200

@auth_bp.route('/forgot-password', methods=['POST'])
@rate_limit_by_email(3)  # 3 attempts per hour per email
@handle_auth_errors
def forgot_password():
    schema = ForgotPasswordSchema()
    data = schema.load(request.get_json(silent=True) or {})
    email = data['email'].strip().lower()
    
    user = User.query.filter_by(email=email, is_active=True).first()
    
    if user:
        reset_token = AuthService.generate_password_reset_token(user.id)
        EmailService.send_password_reset_email(email, reset_token, user.first_name)
        AuditService.log(user.id, 'password_reset_requested')
    
    return jsonify({
        'message': 'If an account with that email exists, a reset link has been sent.'
    }), 200

@auth_bp.route('/reset-password', methods=['POST'])
@rate_limit_by_token(5)  # 5 attempts per hour per token
@handle_auth_errors
def reset_password():
    schema = ResetPasswordSchema()
    data = schema.load(request.get_json(silent=True) or {})
    token = data['token']
    new_password = data['new_password']
    
    is_strong, message = validate_password_strength(new_password)
    if not is_strong:
        return jsonify({'error': message}), 400
    
    user_id = AuthService.verify_password_reset_token(token)
    if not user_id:
        return jsonify({'error': 'Invalid or expired token'}), 400
    
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    user.set_password(new_password)
    db.session.commit()
    
    AuditService.log(user.id, 'password_reset_completed')
    
    return jsonify({'message': 'Password reset successfully'}), 200

@auth_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
@rate_limit_by_user(10)  # 10 attempts per minute per user
@handle_auth_errors
def refresh_token():
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user or not user.is_active:
        return jsonify({'error': 'User not found or inactive'}), 404
    
    additional_claims = {"role": user.role}
    new_access_token = create_access_token(identity=str(current_user_id), additional_claims=additional_claims)
    
    AuditService.log(user.id, 'token_refreshed')
    
    return jsonify({
        'access_token': new_access_token
    }), 200

@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
@rate_limit_by_user(10)  # 10 attempts per minute per user
@handle_auth_errors
def logout():
    current_user_id = get_jwt_identity()
    AuditService.log(current_user_id, 'logout')
    
    response = jsonify({'message': 'Successfully logged out'})
    unset_jwt_cookies(response)
    return response, 200

@auth_bp.route('/health', methods=['GET'])
@limiter.exempt
def health_check():
    return jsonify({'status': 'healthy', 'service': 'auth'})