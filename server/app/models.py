# app/models.py
from datetime import datetime, timedelta
import bcrypt
import secrets
import uuid
from sqlalchemy import event
from app.extensions import db

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(50), nullable=False)
    last_name = db.Column(db.String(50), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='user')
    is_active = db.Column(db.Boolean, default=True)
    is_verified = db.Column(db.Boolean, default=False)
    mfa_enabled = db.Column(db.Boolean, default=False)
    mfa_secret = db.Column(db.String(128), nullable=True)
    onboarding_completed = db.Column(db.Boolean, default=False)
    first_login = db.Column(db.Boolean, default=True)
    last_login = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # New security fields
    login_attempts = db.Column(db.Integer, default=0, nullable=False)
    locked_until = db.Column(db.DateTime, nullable=True)
    password_changed_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    audits = db.relationship('AuditLog', backref='user', lazy=True)
    password_resets = db.relationship('PasswordReset', backref='user', lazy=True)
    onboarding = db.relationship('UserOnboarding', backref='user', uselist=False, lazy=True)
    
    def set_password(self, password):
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        self.password_changed_at = datetime.utcnow()
        self.login_attempts = 0
        self.locked_until = None
    
    def check_password(self, password):
        if self.locked_until and self.locked_until > datetime.utcnow():
            return False
            
        is_valid = bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
        
        if not is_valid:
            self.login_attempts += 1
            if self.login_attempts >= 5:
                self.locked_until = datetime.utcnow() + timedelta(minutes=30)
            db.session.commit()
        else:
            if self.login_attempts > 0:
                self.login_attempts = 0
                self.locked_until = None
                db.session.commit()
                
        return is_valid
    
    def is_account_locked(self):
        if self.locked_until and self.locked_until > datetime.utcnow():
            return True
        elif self.locked_until and self.locked_until <= datetime.utcnow():
            self.locked_until = None
            self.login_attempts = 0
            db.session.commit()
        return False
    
    def get_account_lock_time(self):
        if self.locked_until and self.locked_until > datetime.utcnow():
            return max(0, int((self.locked_until - datetime.utcnow()).total_seconds() / 60))
        return 0
    
    def to_dict(self):
        return {
            'id': self.id,
            'email': self.email,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'role': self.role,
            'is_active': self.is_active,
            'mfa_enabled': self.mfa_enabled,
            'onboarding_completed': self.onboarding_completed,
            'first_login': self.first_login,
            'last_login': self.last_login.isoformat() if self.last_login else None,
            'created_at': self.created_at.isoformat(),
            'is_verified': self.is_verified
        }

class PasswordReset(db.Model):
    __tablename__ = 'password_resets'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    token = db.Column(db.String(100), unique=True, nullable=False, index=True)
    expires_at = db.Column(db.DateTime, nullable=False)
    is_used = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    
    def is_valid(self):
        return not self.is_used and self.expires_at > datetime.utcnow()
    
    def mark_used(self):
        self.is_used = True
        db.session.commit()

class AuditLog(db.Model):
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    action = db.Column(db.String(100), nullable=False)
    resource = db.Column(db.String(100))
    resource_id = db.Column(db.String(50))
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    details = db.Column(db.Text)
    status = db.Column(db.String(20), default='success')
    endpoint = db.Column(db.String(255))
    method = db.Column(db.String(10))
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'action': self.action,
            'resource': self.resource,
            'resource_id': self.resource_id,
            'ip_address': self.ip_address,
            'user_agent': self.user_agent,
            'timestamp': self.timestamp.isoformat(),
            'details': self.details,
            'status': self.status,
            'endpoint': self.endpoint,
            'method': self.method
        }

class CompanyApp(db.Model):
    __tablename__ = 'company_apps'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    app_url = db.Column(db.String(255), nullable=False)
    sso_callback_url = db.Column(db.String(255), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    client_id = db.Column(db.String(50), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))
    client_secret = db.Column(db.String(100), unique=True, nullable=False, default=lambda: secrets.token_urlsafe(32))
    allowed_roles = db.Column(db.JSON, default=list)
    allowed_ips = db.Column(db.JSON, default=list)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'app_url': self.app_url,
            'sso_callback_url': self.sso_callback_url,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat(),
            'client_id': self.client_id,
            'allowed_roles': self.allowed_roles
        }
    
    def is_role_allowed(self, role):
        if not self.allowed_roles:
            return True
        return role in self.allowed_roles
    
    def is_ip_allowed(self, ip_address):
        if not self.allowed_ips:
            return True
        return ip_address in self.allowed_ips

class UserOnboarding(db.Model):
    __tablename__ = 'user_onboarding'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False)
    step_completed = db.Column(db.Integer, default=0)
    profile_data = db.Column(db.JSON)
    completed_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def mark_completed(self):
        self.step_completed = 100
        self.completed_at = datetime.utcnow()
        db.session.commit()
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'step_completed': self.step_completed,
            'profile_data': self.profile_data,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

class TokenBlocklist(db.Model):
    __tablename__ = 'token_blocklist'
    
    id = db.Column(db.Integer, primary_key=True)
    jti = db.Column(db.String(36), nullable=False, index=True)
    token_type = db.Column(db.String(10), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'jti': self.jti,
            'token_type': self.token_type,
            'user_id': self.user_id,
            'expires_at': self.expires_at.isoformat(),
            'created_at': self.created_at.isoformat()
        }

@event.listens_for(User, 'before_update')
def update_updated_at(mapper, connection, target):
    target.updated_at = datetime.utcnow()

@event.listens_for(UserOnboarding, 'before_update')
def update_onboarding_updated_at(mapper, connection, target):
    target.updated_at = datetime.utcnow()