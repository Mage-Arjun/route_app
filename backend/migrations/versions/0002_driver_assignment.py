"""Persist the authenticated user's driver/person assignment."""
from alembic import op
import sqlalchemy as sa

revision = "0002_driver_assignment"
down_revision = "0001_initial"
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    op.add_column("users", sa.Column("person_id", sa.Integer(), nullable=True))
    if bind.dialect.name == "sqlite":
        # SQLite supports adding the nullable column and a unique index, but
        # not adding standalone constraints with ALTER TABLE.
        op.create_index("uq_users_person_id", "users", ["person_id"], unique=True)
    else:
        op.create_unique_constraint("uq_users_person_id", "users", ["person_id"])
        op.create_foreign_key("fk_users_person_id_people", "users", "people", ["person_id"], ["id"])

def downgrade():
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        op.drop_index("uq_users_person_id", table_name="users")
    else:
        op.drop_constraint("fk_users_person_id_people", "users", type_="foreignkey")
        op.drop_constraint("uq_users_person_id", "users", type_="unique")
    op.drop_column("users", "person_id")
