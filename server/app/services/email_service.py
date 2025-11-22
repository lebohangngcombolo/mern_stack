# app/services/email_service.py

import os
from flask import current_app, render_template
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

class EmailService:

    @staticmethod
    def send_temporary_password(email, temporary_password, first_name):
        subject = "Welcome to Company Hub - Your Temporary Password"

        html_content = render_template(
            "emails/temporary_password.html",
            first_name=first_name,
            temporary_password=temporary_password
        )

        EmailService._send_email(email, subject, html_content)

    @staticmethod
    def send_password_reset_email(email, reset_token, first_name):
        reset_url = f"{current_app.config['FRONTEND_URL']}/reset-password?token={reset_token}"

        subject = "Password Reset Request - Company Hub"

        html_content = render_template(
            "emails/password_reset.html",
            first_name=first_name,
            reset_url=reset_url
        )

        EmailService._send_email(email, subject, html_content)

    @staticmethod
    def _send_email(to_email, subject, html_content):
        try:
            message = Mail(
                from_email=current_app.config["SENDGRID_SENDER"],
                to_emails=to_email,
                subject=subject,
                html_content=html_content
            )

            sg = SendGridAPIClient(current_app.config["SENDGRID_API_KEY"])
            sg.send(message)

        except Exception as e:
            current_app.logger.error(
                f"Failed to send email to {to_email}: {str(e)}"
            )
