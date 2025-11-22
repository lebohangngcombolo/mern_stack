# app/services/mfa_service.py
import pyotp
import qrcode
import base64
from io import BytesIO
from app.models import db, User

class MFAService:
    @staticmethod
    def generate_mfa_secret():
        return pyotp.random_base32()
    
    @staticmethod
    def generate_provisioning_uri(email, secret, issuer):
        totp = pyotp.TOTP(secret)
        return totp.provisioning_uri(name=email, issuer_name=issuer)
    
    @staticmethod
    def generate_qr_code(provisioning_uri):
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(provisioning_uri)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        buffered = BytesIO()
        img.save(buffered, format="PNG")
        return base64.b64encode(buffered.getvalue()).decode()
    
    @staticmethod
    def verify_totp(secret, token):
        totp = pyotp.TOTP(secret)
        return totp.verify(token)
    
    @staticmethod
    def enable_mfa_for_user(user_id, secret):
        user = User.query.get(user_id)
        if user:
            user.mfa_secret = secret
            user.mfa_enabled = True
            db.session.commit()
            return True
        return False