# app/services/email_service.py
from flask_mail import Mail, Message
from flask import current_app

mail = Mail()

class EmailService:
    @staticmethod
    def send_temporary_password(email, temporary_password, first_name):
        subject = "Welcome to Company Hub - Your Temporary Password"
        body = f"""
        Hello {first_name},
        
        Your account has been created in the Company Hub.
        
        Your temporary password is: {temporary_password}
        
        Please log in and change your password immediately. You will also be prompted to set up Multi-Factor Authentication (MFA) for security.
        
        Best regards,
        Company Hub Team
        """
        
        EmailService._send_email(email, subject, body)
    
    @staticmethod
    def send_password_reset_email(email, reset_token, first_name):
        reset_url = f"{current_app.config['FRONTEND_URL']}/reset-password?token={reset_token}"
        
        subject = "Password Reset Request - Company Hub"
        body = f"""
        Hello {first_name},
        
        You requested a password reset for your Company Hub account.
        
        Click here to reset your password: {reset_url}
        
        This link will expire in 1 hour.
        
        If you didn't request this, please ignore this email.
        
        Best regards,
        Company Hub Team
        """
        
        EmailService._send_email(email, subject, body)
    
    @staticmethod
    def _send_email(to, subject, body):
        try:
            msg = Message(
                subject=subject,
                sender=current_app.config['MAIL_USERNAME'],
                recipients=[to],
                body=body
            )
            mail.send(msg)
        except Exception as e:
            current_app.logger.error(f"Failed to send email to {to}: {str(e)}")