"""Add customers, first-class routes, trips, stops, POD and approvals."""

from alembic import op
import sqlalchemy as sa


revision = "0004_delivery_product"
down_revision = "0003_user_person_fk"
branch_labels = None
depends_on = None


def upgrade():
    # Development databases may already have these tables from SQLAlchemy's
    # create_all() bootstrap before Alembic was introduced. Treat that state
    # as an already-applied schema so `routeos.sh` remains safe to rerun.
    if sa.inspect(op.get_bind()).has_table("customers"):
        return
    op.create_table(
        "customers",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("code", sa.String(32), nullable=False, unique=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("contact_name", sa.String(120)),
        sa.Column("phone", sa.String(32)),
        sa.Column("email", sa.String(160)),
        sa.Column("address", sa.Text),
        sa.Column("latitude", sa.Float),
        sa.Column("longitude", sa.Float),
        sa.Column("service_notes", sa.Text),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True)),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "routes",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("code", sa.String(32), nullable=False, unique=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("assigned_driver_id", sa.Integer, sa.ForeignKey("users.id")),
        sa.Column("assigned_vehicle_id", sa.Integer, sa.ForeignKey("vehicles.id")),
        sa.Column("created_by_id", sa.Integer, sa.ForeignKey("users.id")),
        sa.Column("version", sa.Integer, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True)),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "route_stops",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("route_id", sa.Integer, sa.ForeignKey("routes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("customer_id", sa.Integer, sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("sequence", sa.Integer, nullable=False),
        sa.Column("planned_arrival_time", sa.String(16)),
        sa.Column("service_duration_mins", sa.Integer, nullable=False),
        sa.Column("notes", sa.Text),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True)),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("route_id", "sequence", name="uq_route_stop_sequence"),
    )
    op.create_table(
        "trips",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("code", sa.String(40), nullable=False, unique=True),
        sa.Column("route_id", sa.Integer, sa.ForeignKey("routes.id"), nullable=False),
        sa.Column("driver_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.Integer, sa.ForeignKey("vehicles.id")),
        sa.Column("trip_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("start_time", sa.DateTime(timezone=True)),
        sa.Column("end_time", sa.DateTime(timezone=True)),
        sa.Column("total_distance_km", sa.Float, nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True)),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "trip_stops",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("trip_id", sa.Integer, sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("route_stop_id", sa.Integer, sa.ForeignKey("route_stops.id"), nullable=False),
        sa.Column("customer_id", sa.Integer, sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("sequence", sa.Integer, nullable=False),
        sa.Column("arrival_time", sa.DateTime(timezone=True)),
        sa.Column("departure_time", sa.DateTime(timezone=True)),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("notes", sa.Text),
        sa.Column("driver_notes", sa.Text),
        sa.Column("receiver_name", sa.String(120)),
        sa.Column("failure_reason", sa.Text),
        sa.Column("delivery_latitude", sa.Float),
        sa.Column("delivery_longitude", sa.Float),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True)),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("trip_id", "sequence", name="uq_trip_stop_sequence"),
    )
    op.create_table(
        "proofs_of_delivery",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("trip_stop_id", sa.Integer, sa.ForeignKey("trip_stops.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("receiver_name", sa.String(120), nullable=False),
        sa.Column("notes", sa.Text),
        sa.Column("signature_data", sa.Text),
        sa.Column("photo_path", sa.String(255)),
        sa.Column("latitude", sa.Float),
        sa.Column("longitude", sa.Float),
        sa.Column("captured_at", sa.DateTime(timezone=True)),
        sa.Column("created_by_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
    )
    op.create_table(
        "route_changes",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("route_id", sa.Integer, sa.ForeignKey("routes.id"), nullable=False),
        sa.Column("customer_id", sa.Integer, sa.ForeignKey("customers.id")),
        sa.Column("change_type", sa.String(32), nullable=False),
        sa.Column("recommended_sequence", sa.Integer),
        sa.Column("additional_distance_km", sa.Float, nullable=False),
        sa.Column("additional_time_mins", sa.Float, nullable=False),
        sa.Column("reason", sa.Text),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("requested_by_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("approved_by_id", sa.Integer, sa.ForeignKey("users.id")),
        sa.Column("decided_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True)),
    )


def downgrade():
    for table in ("route_changes", "proofs_of_delivery", "trip_stops", "trips", "route_stops", "routes", "customers"):
        op.drop_table(table)
