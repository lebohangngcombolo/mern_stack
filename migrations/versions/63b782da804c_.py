"""empty message

Revision ID: 63b782da804c
Revises: e43a566479c4
Create Date: 2025-11-22 09:25:26.645825
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '63b782da804c'
down_revision = 'e43a566479c4'
branch_labels = None
depends_on = None


def upgrade():
    # ---------- AUDIT LOGS ----------
    with op.batch_alter_table('audit_logs', schema=None) as batch_op:
        batch_op.add_column(sa.Column('status', sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column('endpoint', sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column('method', sa.String(length=10), nullable=True))

    # ---------- COMPANY APPS (FIXED) ----------
    # Step 1: Add new columns as NULLABLE first
    with op.batch_alter_table('company_apps', schema=None) as batch_op:
        batch_op.add_column(sa.Column('client_id', sa.String(length=50), nullable=True))
        batch_op.add_column(sa.Column('client_secret', sa.String(length=100), nullable=True))
        batch_op.add_column(sa.Column('allowed_roles', sa.JSON(), nullable=True))
        batch_op.add_column(sa.Column('allowed_ips', sa.JSON(), nullable=True))

    # Step 2: Populate existing rows with generated values
    # Uses gen_random_uuid() from pgcrypto. If pgcrypto isn't enabled, I can give you a fallback.
    op.execute("""
        UPDATE company_apps
        SET 
            client_id = gen_random_uuid()::text,
            client_secret = gen_random_uuid()::text
        WHERE client_id IS NULL;
    """)

    # Step 3: Enforce NOT NULL + unique constraints AFTER values exist
    with op.batch_alter_table('company_apps', schema=None) as batch_op:
        batch_op.alter_column('client_id', nullable=False)
        batch_op.alter_column('client_secret', nullable=False)
        batch_op.create_unique_constraint('uq_company_apps_client_id', ['client_id'])
        batch_op.create_unique_constraint('uq_company_apps_client_secret', ['client_secret'])

    # ---------- PASSWORD_RESETS ----------
    with op.batch_alter_table('password_resets', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ip_address', sa.String(length=45), nullable=True))
        batch_op.add_column(sa.Column('user_agent', sa.Text(), nullable=True))

    # ---------- USERS ----------
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('login_attempts', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('locked_until', sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column('password_changed_at', sa.DateTime(), nullable=True))


def downgrade():
    # ---------- USERS ----------
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('password_changed_at')
        batch_op.drop_column('locked_until')
        batch_op.drop_column('login_attempts')

    # ---------- PASSWORD_RESETS ----------
    with op.batch_alter_table('password_resets', schema=None) as batch_op:
        batch_op.drop_column('user_agent')
        batch_op.drop_column('ip_address')

    # ---------- COMPANY APPS ----------
    with op.batch_alter_table('company_apps', schema=None) as batch_op:
        batch_op.drop_constraint('uq_company_apps_client_id', type_='unique')
        batch_op.drop_constraint('uq_company_apps_client_secret', type_='unique')
        batch_op.drop_column('allowed_ips')
        batch_op.drop_column('allowed_roles')
        batch_op.drop_column('client_secret')
        batch_op.drop_column('client_id')

    # ---------- AUDIT LOGS ----------
    with op.batch_alter_table('audit_logs', schema=None) as batch_op:
        batch_op.drop_column('method')
        batch_op.drop_column('endpoint')
        batch_op.drop_column('status')
