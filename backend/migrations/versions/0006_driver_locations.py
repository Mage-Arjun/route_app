"""Track a driver's phone location without requiring a vehicle."""

from alembic import op
import sqlalchemy as sa


revision = "0006_driver_locations"
down_revision = "0005_route_geometry"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "driver_locations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("trip_id", sa.Integer(), sa.ForeignKey("trips.id"), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("accuracy", sa.Float(), nullable=True),
        sa.Column("last_seen", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("driver_id", name="uq_driver_locations_driver_id"),
    )
    op.create_index("ix_driver_locations_driver_id", "driver_locations", ["driver_id"])
    op.create_index("ix_driver_locations_trip_id", "driver_locations", ["trip_id"])
    op.create_index("ix_driver_locations_last_seen", "driver_locations", ["last_seen"])


def downgrade():
    op.drop_index("ix_driver_locations_last_seen", table_name="driver_locations")
    op.drop_index("ix_driver_locations_trip_id", table_name="driver_locations")
    op.drop_index("ix_driver_locations_driver_id", table_name="driver_locations")
    op.drop_table("driver_locations")
