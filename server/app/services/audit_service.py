# app/services/audit_service.py
from app.models import db, AuditLog
from flask import request

class AuditService:
    @staticmethod
    def log(user_id, action, resource=None, resource_id=None, details=None):
        try:
            audit_log = AuditLog(
                user_id=user_id,
                action=action,
                resource=resource,
                resource_id=str(resource_id) if resource_id else None,
                ip_address=request.remote_addr if request else None,
                user_agent=request.headers.get('User-Agent') if request else None,
                details=details
            )
            db.session.add(audit_log)
            db.session.commit()
        except Exception as e:
            current_app.logger.error(f"Audit log failed: {str(e)}")