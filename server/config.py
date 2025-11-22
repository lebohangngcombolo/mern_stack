# config.py
import os
from datetime import timedelta

class Config:
    # Basic
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'super-secret-key-change-in-production'
    
    # Database
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///instance/app.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # JWT
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or 'jwt-super-secret-key'
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    
    SUPER_ADMIN_EMAIL = os.environ.get('SUPER_ADMIN_EMAIL')

    # ----------------------------
    # SendGrid Email Configuration
    # ----------------------------
    SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY")
    SENDGRID_SENDER = os.environ.get("SENDGRID_SENDER")  # e.g. no-reply@companyhub.com
    # ----------------------------

    # App URLs
    FRONTEND_URL = os.environ.get('FRONTEND_URL', 'http://localhost:3000')
    BACKEND_URL = os.environ.get('BACKEND_URL', 'http://localhost:5000')
    
    # SSO
    SSO_JWT_SECRET = os.environ.get('SSO_JWT_SECRET') or 'sso-shared-secret-key'
    
    # MFA
    MFA_ISSUER = os.environ.get('MFA_ISSUER', 'Company Hub')
    
    # Rate Limiting
    RATELIMIT_STORAGE_URL = "memory://"  
    RATELIMIT_STRATEGY = "fixed-window"
    RATELIMIT_HEADERS_ENABLED = True

class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
