# app/services/audit_service.py
from flask import request, has_request_context, current_app
from app.models import db, AuditLog
import json

class AuditService:
    @staticmethod
    def log(user_id, action, resource=None, resource_id=None, details=None):
        try:
            # Avoid serialization errors if details is dict
            if isinstance(details, dict):
                try:
                    details = json.dumps(details)
                except Exception:
                    details = str(details)

            # Check if inside a request (API call) or running in background
            if has_request_context():
                ip_address = request.remote_addr
                user_agent = request.headers.get("User-Agent")
            else:
                ip_address = "SYSTEM"
                user_agent = "SYSTEM"

            audit_log = AuditLog(
                user_id=user_id,
                action=action,
                resource=resource,
                resource_id=str(resource_id) if resource_id else None,
                ip_address=ip_address,
                user_agent=user_agent,
                details=details
            )

            db.session.add(audit_log)
            db.session.commit()

        except Exception as e:
            current_app.logger.error(f"Audit log failed: {str(e)}")