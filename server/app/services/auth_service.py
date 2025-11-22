# app/services/auth_service.py
import secrets
from datetime import datetime, timedelta
from app.models import db, User, PasswordReset

class AuthService:
    @staticmethod
    def generate_password_reset_token(user_id):
        token = secrets.token_urlsafe(32)
        expires_at = datetime.utcnow() + timedelta(hours=1)
        
        # Invalidate previous tokens
        PasswordReset.query.filter_by(user_id=user_id, is_used=False).update({'is_used': True})
        
        reset_token = PasswordReset(
            user_id=user_id,
            token=token,
            expires_at=expires_at
        )
        db.session.add(reset_token)
        db.session.commit()
        
        return token
    
    @staticmethod
    def verify_password_reset_token(token):
        reset_token = PasswordReset.query.filter_by(token=token, is_used=False).first()
        
        if not reset_token or reset_token.expires_at < datetime.utcnow():
            return None
        
        reset_token.is_used = True
        db.session.commit()
        
        return reset_token.user_id
    
    @staticmethod
    def generate_temporary_password():
        """Generate a secure temporary password"""
        import string
        import random
        
        # Generate 12 character password with mix of characters
        characters = string.ascii_letters + string.digits + "!@#$%"
        return ''.join(random.choice(characters) for i in range(12))