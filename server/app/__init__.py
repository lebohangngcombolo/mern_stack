# app/__init__.py
import os
from flask import Flask
from dotenv import load_dotenv
from config import config
from app.extensions import db, jwt, migrate, cors, limiter
from app.services.email_service import EmailService
from app.services.auth_service import AuthService

# Load environment variables from .env
load_dotenv()

def create_app(config_name='default'):
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_object(config[config_name])
    os.makedirs(app.instance_path, exist_ok=True)

    # Initialize extensions
    db.init_app(app)
    jwt.init_app(app)
    migrate.init_app(app, db)
    cors.init_app(app)
    limiter.init_app(app)

    # Register blueprints
    from app.routes.auth import auth_bp
    from app.routes.admin import admin_bp
    from app.routes.user import user_bp
    from app.routes.sso import sso_bp

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    app.register_blueprint(user_bp, url_prefix='/api/user')
    app.register_blueprint(sso_bp, url_prefix='/api/sso')

    # Create tables & super admin
    with app.app_context():
        from app.models import User

        # Auto-create tables only in DEBUG
        if app.config.get('DEBUG', False):
            try:
                db.create_all()
                print("Tables created successfully (development mode).")
            except Exception as e:
                print(f"Skipping create_all due to migration state: {e}")

        super_admin_email = app.config.get('SUPER_ADMIN_EMAIL')
        if not super_admin_email:
            print("⚠️ SUPER_ADMIN_EMAIL not set. Skipping super admin creation.")
        else:
            try:
                # Attempt to access user table – skip if schema is outdated
                super_admin = User.query.filter_by(email=super_admin_email).first()

                if super_admin:
                    print(f"Super admin already exists: {super_admin_email}")
                else:
                    temp_password = AuthService.generate_temporary_password()
                    super_admin = User(
                        email=super_admin_email,
                        first_name='Super',
                        last_name='Admin',
                        role='super_admin',
                        is_verified=True,
                        first_login=False,
                        onboarding_completed=True
                    )
                    super_admin.set_password(temp_password)
                    db.session.add(super_admin)
                    db.session.commit()
                    print(f"Super admin created successfully: {super_admin_email}")
                    print(f"Temporary password: {temp_password}")

                    # Attempt email sending
                    try:
                        EmailService.send_temporary_password(
                            email=super_admin_email,
                            temporary_password=temp_password,
                            first_name='Super'
                        )
                        print(f"Temporary password sent via email to: {super_admin_email}")
                    except Exception as e:
                        print(f"Failed to send temporary password email: {e}")

            except Exception as e:
                # Prevents crashes during migrations
                print(f"Skipping super admin creation due to DB not ready: {e}")

    return app
