from datetime import datetime, date
from typing import Optional, List, Any, Literal
from pydantic import BaseModel, EmailStr, Field


# ─── Auth ────────────────────────────────────────────────
class Token(BaseModel):
    access_token: str
    token_type: str
    user: "UserOut"

class LoginRequest(BaseModel):
    email: str
    password: str


class DriverRegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    phone: Optional[str] = None


class LocationPush(BaseModel):
    lat: float
    lng: float
    accuracy: Optional[float] = None
    trip_id: Optional[int] = None
    timestamp: str  # ISO8601


# ─── Users ───────────────────────────────────────────────
class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    role: Literal["admin", "driver", "supervisor"] = "driver"
    phone: Optional[str] = None

class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    phone: Optional[str] = None
    role: Optional[Literal["admin", "driver", "supervisor"]] = None
    status: Optional[Literal["active", "inactive"]] = None

class UserOut(BaseModel):
    id: int
    name: str
    email: str
    role: str
    phone: Optional[str] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Customers ───────────────────────────────────────────
class CustomerCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    address: Optional[str] = None
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    contact_person: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    customer_type: Literal["retail", "wholesale", "hotel", "pharmacy"] = "retail"
    customer_code: Optional[str] = None
    preferred_visit_time: Optional[str] = None
    service_duration_mins: int = Field(15, ge=5, le=120)
    visit_days: Optional[str] = "[]"
    notes: Optional[str] = None

class CustomerUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    contact_person: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    customer_type: Optional[Literal["retail", "wholesale", "hotel", "pharmacy"]] = None
    preferred_visit_time: Optional[str] = None
    service_duration_mins: Optional[int] = Field(None, ge=5, le=120)
    visit_days: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[Literal["active", "inactive"]] = None

class CustomerOut(BaseModel):
    id: int
    name: str
    address: Optional[str] = None
    latitude: float
    longitude: float
    contact_person: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    customer_type: str
    customer_code: Optional[str] = None
    preferred_visit_time: Optional[str] = None
    service_duration_mins: int
    visit_days: Optional[str] = None
    notes: Optional[str] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Vehicles ────────────────────────────────────────────
class VehicleCreate(BaseModel):
    vehicle_number: str
    registration: Optional[str] = None
    vehicle_type: str = "van"
    capacity_kg: float = 500.0
    assigned_driver_id: Optional[int] = None

class VehicleUpdate(BaseModel):
    vehicle_number: Optional[str] = None
    registration: Optional[str] = None
    vehicle_type: Optional[Literal["van", "truck", "car", "bike"]] = None
    capacity_kg: Optional[float] = Field(None, gt=0)
    assigned_driver_id: Optional[int] = None
    status: Optional[Literal["active", "inactive"]] = None

class VehicleOut(BaseModel):
    id: int
    vehicle_number: str
    registration: Optional[str] = None
    vehicle_type: str
    capacity_kg: float
    assigned_driver_id: Optional[int] = None
    assigned_driver: Optional[UserOut] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Route Stops ─────────────────────────────────────────
class RouteStopOut(BaseModel):
    id: int
    route_id: int
    customer_id: int
    sequence: int
    planned_arrival_time: Optional[str] = None
    service_duration_mins: int
    notes: Optional[str] = None
    status: str
    customer: CustomerOut

    class Config:
        from_attributes = True

class RouteStopCreate(BaseModel):
    customer_id: int
    sequence: Optional[int] = None  # if None, use smart insertion
    planned_arrival_time: Optional[str] = None
    service_duration_mins: int = 15
    notes: Optional[str] = None

class QuickStopCreate(BaseModel):
    name: str
    latitude: float
    longitude: float
    address: Optional[str] = None
    phone: Optional[str] = None
    notes: Optional[str] = None
    sequence: Optional[int] = None
    service_duration_mins: int = 15

class StopReorderRequest(BaseModel):
    stop_ids: List[int]  # ordered list of route_stop IDs



# ─── Routes ──────────────────────────────────────────────
class RouteCreate(BaseModel):
    name: str
    area: Optional[str] = None
    working_days: Optional[str] = "[]"
    start_lat: Optional[float] = None
    start_lng: Optional[float] = None
    start_address: Optional[str] = None
    end_lat: Optional[float] = None
    end_lng: Optional[float] = None
    end_address: Optional[str] = None
    assigned_driver_id: Optional[int] = None
    assigned_vehicle_id: Optional[int] = None

class RouteUpdate(BaseModel):
    name: Optional[str] = None
    area: Optional[str] = None
    working_days: Optional[str] = None
    start_address: Optional[str] = None
    end_address: Optional[str] = None
    assigned_driver_id: Optional[int] = None
    assigned_vehicle_id: Optional[int] = None
    status: Optional[str] = None

class RouteOut(BaseModel):
    id: int
    name: str
    area: Optional[str] = None
    working_days: Optional[str] = None
    start_lat: Optional[float] = None
    start_lng: Optional[float] = None
    start_address: Optional[str] = None
    end_lat: Optional[float] = None
    end_lng: Optional[float] = None
    end_address: Optional[str] = None
    assigned_driver_id: Optional[int] = None
    assigned_vehicle_id: Optional[int] = None
    version: int
    status: str
    created_at: datetime
    assigned_driver: Optional[UserOut] = None
    assigned_vehicle: Optional[VehicleOut] = None
    stops: List[RouteStopOut] = []

    class Config:
        from_attributes = True


# ─── Smart Insertion ─────────────────────────────────────
class InsertionOption(BaseModel):
    position: int          # insert BEFORE this sequence index (1-based)
    after_stop_name: Optional[str] = None
    before_stop_name: Optional[str] = None
    additional_distance_km: float
    additional_time_mins: float
    is_recommended: bool = False
    used_real_roads: bool = False  # True = OSRM road network, False = Haversine fallback

class InsertionResult(BaseModel):
    customer_id: int
    customer_name: str
    options: List[InsertionOption]
    recommended_position: int


# ─── Route Changes ───────────────────────────────────────
class RouteChangeCreate(BaseModel):
    route_id: int
    customer_id: int
    recommended_sequence: int
    additional_distance_km: float
    additional_time_mins: float = 0.0

class RouteChangeOut(BaseModel):
    id: int
    route_id: int
    customer_id: int
    recommended_sequence: int
    additional_distance_km: float
    additional_time_mins: float
    status: str
    requested_by_id: Optional[int] = None
    approved_by_id: Optional[int] = None
    requested_by: Optional[UserOut] = None
    approved_by: Optional[UserOut] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    customer: CustomerOut
    route: Optional[RouteOut] = None

    class Config:
        from_attributes = True


# ─── Route Versions ──────────────────────────────────────
class RouteVersionOut(BaseModel):
    id: int
    route_id: int
    version: int
    change_summary: Optional[str] = None
    changed_by_id: Optional[int] = None
    changed_by: Optional[UserOut] = None
    created_at: datetime
    snapshot: Optional[str] = None

    class Config:
        from_attributes = True


# ─── Trips ───────────────────────────────────────────────
class TripCreate(BaseModel):
    route_id: int
    vehicle_id: Optional[int] = None

class TripStopUpdate(BaseModel):
    status: str  # completed / skipped / closed / refused / partial / rescheduled
    notes: Optional[str] = None
    driver_notes: Optional[str] = None
    # ── Proof of Delivery ──────────────────────────────────
    receiver_name: Optional[str] = None
    signature_data: Optional[str] = None   # base64-encoded signature image
    photo_url: Optional[str] = None        # server-side photo path after upload
    failure_reason: Optional[str] = None
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None

class TripStopOut(BaseModel):
    id: int
    trip_id: int
    route_stop_id: int
    customer_id: int
    sequence: int
    arrival_time: Optional[datetime] = None
    departure_time: Optional[datetime] = None
    status: str
    notes: Optional[str] = None
    driver_notes: Optional[str] = None
    # ── Proof of Delivery ──────────────────────────────────
    receiver_name: Optional[str] = None
    signature_data: Optional[str] = None
    photo_url: Optional[str] = None
    failure_reason: Optional[str] = None
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None
    completed_at: Optional[datetime] = None
    customer: CustomerOut

    class Config:
        from_attributes = True

class TripOut(BaseModel):
    id: int
    route_id: int
    driver_id: int
    vehicle_id: Optional[int] = None
    date: date
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    total_distance_km: float
    completed_stops: int
    total_stops: int
    status: str
    created_at: datetime
    route: Optional[RouteOut] = None
    driver: Optional[UserOut] = None
    vehicle: Optional[VehicleOut] = None
    trip_stops: List[TripStopOut] = []

    class Config:
        from_attributes = True


# ─── Analytics ───────────────────────────────────────────
class DashboardStats(BaseModel):
    total_routes: int
    active_routes: int
    total_customers: int
    total_vehicles: int
    total_drivers: int
    today_trips: int
    today_completed_stops: int
    today_pending_stops: int
    pending_approvals: int

class RouteAnalytics(BaseModel):
    route_id: int
    route_name: str
    total_trips: int
    avg_completion_rate: float
    avg_distance_km: float
    total_stops: int
    recent_trips: List[TripOut] = []


# Update forward ref
Token.model_rebuild()
RouteChangeOut.model_rebuild()
TripOut.model_rebuild()
