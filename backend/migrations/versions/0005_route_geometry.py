"""Store the path drawn or recorded for each delivery route."""

from alembic import op
import sqlalchemy as sa


revision = "0005_route_geometry"
down_revision = "0004_delivery_product"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("routes", sa.Column("geometry", sa.JSON(), nullable=True))


def downgrade():
    op.drop_column("routes", "geometry")
