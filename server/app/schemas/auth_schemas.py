from marshmallow import Schema, fields, validate, ValidationError

class LoginSchema(Schema):
    email = fields.Email(required=True)
    password = fields.Str(required=True, validate=validate.Length(min=1))

class MFASchema(Schema):
    mfa_code = fields.Str(required=True, validate=validate.Length(min=6, max=6))

class ChangePasswordSchema(Schema):
    current_password = fields.Str(required=True, validate=validate.Length(min=1))
    new_password = fields.Str(required=True, validate=validate.Length(min=8))

class ForgotPasswordSchema(Schema):
    email = fields.Email(required=True)

class ResetPasswordSchema(Schema):
    token = fields.Str(required=True)
    new_password = fields.Str(required=True, validate=validate.Length(min=8))

class SetupMFASchema(Schema):
    pass

class VerifyMFASetupSchema(Schema):
    mfa_code = fields.Str(required=True, validate=validate.Length(min=6, max=6))

class GenerateSSOTokenSchema(Schema):
    app_id = fields.Str(required=True)

class ValidateSSOTokenSchema(Schema):
    token = fields.Str(required=True)