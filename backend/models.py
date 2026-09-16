from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Date,
    ForeignKey, Text, Boolean
)
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(String, default="driver")  # admin / driver / supervisor
    phone = Column(String)
    status = Column(String, default="active")  # active / inactive
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    assigned_routes = relationship("Route", back_populates="assigned_driver", foreign_keys="Route.assigned_driver_id")
    assigned_vehicle = relationship("Vehicle", back_populates="assigned_driver", foreign_keys="Vehicle.assigned_driver_id")
    trips = relationship("Trip", back_populates="driver")


class Customer(Base):
    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    address = Column(Text)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    contact_person = Column(String)
    phone = Column(String)
    email = Column(String)
    customer_type = Column(String, default="retail")  # retail / wholesale / hotel / pharmacy
    customer_code = Column(String)
    preferred_visit_time = Column(String)  # e.g. "09:00-11:00"
    service_duration_mins = Column(Integer, default=15)
    visit_days = Column(Text, default="[]")  # JSON array of days
    notes = Column(Text)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    route_stops = relationship("RouteStop", back_populates="customer")


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, index=True)
    vehicle_number = Column(String, unique=True, nullable=False)
    registration = Column(String)
    vehicle_type = Column(String, default="van")  # van / truck / car / bike
    capacity_kg = Column(Float, default=500.0)
    assigned_driver_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    assigned_driver = relationship("User", back_populates="assigned_vehicle", foreign_keys=[assigned_driver_id])
    routes = relationship("Route", back_populates="assigned_vehicle")
    trips = relationship("Trip", back_populates="vehicle")


class Route(Base):
    __tablename__ = "routes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    area = Column(String)
    working_days = Column(Text, default="[]")  # JSON array e.g. ["Monday","Thursday"]
    start_lat = Column(Float)
    start_lng = Column(Float)
    start_address = Column(String)
    end_lat = Column(Float)
    end_lng = Column(Float)
    end_address = Column(String)
    assigned_driver_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    assigned_vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)
    version = Column(Integer, default=1)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    assigned_driver = relationship("User", back_populates="assigned_routes", foreign_keys=[assigned_driver_id])
    assigned_vehicle = relationship("Vehicle", back_populates="routes", foreign_keys=[assigned_vehicle_id])
    stops = relationship("RouteStop", back_populates="route", order_by="RouteStop.sequence", cascade="all, delete-orphan")
    versions = relationship("RouteVersion", back_populates="route", cascade="all, delete-orphan")
    trips = relationship("Trip", back_populates="route")
    pending_changes = relationship("RouteChange", back_populates="route", cascade="all, delete-orphan")


class RouteStop(Base):
    __tablename__ = "route_stops"

    id = Column(Integer, primary_key=True, index=True)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)
    sequence = Column(Integer, nullable=False)
    planned_arrival_time = Column(String)  # e.g. "09:30"
    service_duration_mins = Column(Integer, default=15)
    notes = Column(Text)
    status = Column(String, default="active")  # active / removed

    route = relationship("Route", back_populates="stops")
    customer = relationship("Customer", back_populates="route_stops")
    trip_stops = relationship("TripStop", back_populates="route_stop")


class RouteVersion(Base):
    __tablename__ = "route_versions"

    id = Column(Integer, primary_key=True, index=True)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    version = Column(Integer, nullable=False)
    snapshot = Column(Text)  # JSON snapshot of stops
    change_summary = Column(Text)
    changed_by_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    route = relationship("Route", back_populates="versions")
    changed_by = relationship("User")


class RouteChange(Base):
    __tablename__ = "route_changes"

    id = Column(Integer, primary_key=True, index=True)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)
    recommended_sequence = Column(Integer)
    additional_distance_km = Column(Float)
    additional_time_mins = Column(Float)
    status = Column(String, default="pending")  # pending / approved / rejected
    requested_by_id = Column(Integer, ForeignKey("users.id"))
    approved_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    route = relationship("Route", back_populates="pending_changes")
    customer = relationship("Customer")
    requested_by = relationship("User", foreign_keys=[requested_by_id])
    approved_by = relationship("User", foreign_keys=[approved_by_id])


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)
    date = Column(Date, default=lambda: datetime.now(timezone.utc).date())
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)
    total_distance_km = Column(Float, default=0.0)
    completed_stops = Column(Integer, default=0)
    total_stops = Column(Integer, default=0)
    status = Column(String, default="active")  # active / completed / cancelled
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    route = relationship("Route", back_populates="trips")
    driver = relationship("User", back_populates="trips")
    vehicle = relationship("Vehicle", back_populates="trips")
    trip_stops = relationship("TripStop", back_populates="trip", order_by="TripStop.sequence", cascade="all, delete-orphan")


class TripStop(Base):
    __tablename__ = "trip_stops"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id"), nullable=False)
    route_stop_id = Column(Integer, ForeignKey("route_stops.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)
    sequence = Column(Integer, nullable=False)
    arrival_time = Column(DateTime, nullable=True)
    departure_time = Column(DateTime, nullable=True)
    status = Column(String, default="pending")
    # pending / completed / skipped / closed / refused / partial / rescheduled
    notes = Column(Text)
    driver_notes = Column(Text)

    # ── Proof of Delivery (PoD) Fields ──────────────────────
    receiver_name = Column(String, nullable=True)          # Name of person who received
    signature_data = Column(Text, nullable=True)           # Base64 signature image data
    photo_url = Column(String, nullable=True)              # URL/path to delivery photo
    failure_reason = Column(String, nullable=True)         # Reason for skip/refuse/close
    delivery_latitude = Column(Float, nullable=True)       # GPS lat at delivery time
    delivery_longitude = Column(Float, nullable=True)      # GPS lng at delivery time
    completed_at = Column(DateTime, nullable=True)         # Actual completion timestamp

    trip = relationship("Trip", back_populates="trip_stops")
    route_stop = relationship("RouteStop", back_populates="trip_stops")
    customer = relationship("Customer")
