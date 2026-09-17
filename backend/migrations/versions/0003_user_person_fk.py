"""Add the driver user -> person foreign key on SQLite as well as other databases."""
from alembic import op

revision = "0003_user_person_fk"
down_revision = "0002_driver_assignment"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("users", recreate="always") as batch:
            batch.create_foreign_key(
                "fk_users_person_id_people",
                "people",
                ["person_id"],
                ["id"],
            )


def downgrade():
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("users", recreate="always") as batch:
            batch.drop_constraint("fk_users_person_id_people", type_="foreignkey")
