from flask import request, has_request_context, current_app
from app.models import db, AuditLog
import json

class AuditService:
    @staticmethod
    def log(user_id, action, resource=None, resource_id=None, details=None):
        try:
            # Convert details dict → JSON
            if isinstance(details, dict):
                try:
                    details = json.dumps(details)
                except Exception:
                    details = str(details)

            # handle cases where request exists
            if has_request_context():
                # Render uses proxy → extract real client IP
                forwarded_for = request.headers.get("X-Forwarded-For", None)
                if forwarded_for:
                    # Real IP is first in the chain
                    ip_address = forwarded_for.split(",")[0].strip()
                else:
                    ip_address = request.remote_addr

                user_agent = request.headers.get("User-Agent")
            else:
                # Background / system operation
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
            try:
                db.session.rollback()
            except:
                pass

            if current_app:
                current_app.logger.error(f"[AUDIT] Failed to log action: {str(e)}")
