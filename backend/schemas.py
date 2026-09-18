from datetime import datetime
from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field

class LoginRequest(BaseModel):
    email: str
    password: str

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int; email: str; role: str; status: str; created_at: datetime

class Token(BaseModel):
    access_token: str; token_type: str = "bearer"; user: UserOut

class PersonCreate(BaseModel):
    identifier: str = Field(min_length=2, max_length=32)
    name: str = Field(min_length=2, max_length=120)

class VehicleCreate(BaseModel):
    identifier: str = Field(min_length=2, max_length=32)
    name: str = Field(min_length=2, max_length=120)
    type: str = "van"

class LocationCreate(BaseModel):
    code: str = Field(min_length=2, max_length=32)
    name: str = Field(min_length=2, max_length=120)
    type: str = "place"
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

class JourneyCreate(BaseModel):
    identifier: str = Field(min_length=2, max_length=32)
    vehicle_id: int
    origin_location_id: int
    destination_location_id: int | None = None

class LocationUpdate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class CustomerCreate(BaseModel):
    code: str = Field(min_length=2, max_length=32)
    name: str = Field(min_length=2, max_length=160)
    contact_name: str | None = Field(default=None, max_length=120)
    phone: str | None = Field(default=None, max_length=32)
    email: str | None = Field(default=None, max_length=160)
    address: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    service_notes: str | None = None
    status: str = Field(default="active", max_length=24)


class CustomerUpdate(CustomerCreate):
    pass


class RouteCreate(BaseModel):
    code: str = Field(min_length=2, max_length=32)
    name: str = Field(min_length=2, max_length=160)
    description: str | None = None
    geometry: list[list[float]] = Field(default_factory=list, min_length=0)
    assigned_driver_id: int | None = None
    assigned_vehicle_id: int | None = None
    status: str = Field(default="active", max_length=24)


class RouteUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=160)
    description: str | None = None
    geometry: list[list[float]] | None = None
    assigned_driver_id: int | None = None
    assigned_vehicle_id: int | None = None
    status: str | None = Field(default=None, max_length=24)


class RouteStopCreate(BaseModel):
    customer_id: int
    sequence: int = Field(ge=1)
    planned_arrival_time: str | None = Field(default=None, max_length=16)
    service_duration_mins: int = Field(default=10, ge=1, le=480)
    notes: str | None = None


class ReorderStopsRequest(BaseModel):
    stop_ids: list[int] = Field(min_length=1)


class TripCreate(BaseModel):
    route_id: int
    driver_id: int | None = None
    vehicle_id: int | None = None
    trip_date: datetime | None = None


class TripStopUpdate(BaseModel):
    action: Literal["arrive", "complete", "skip", "fail"]
    receiver_name: str | None = Field(default=None, max_length=120)
    driver_notes: str | None = None
    failure_reason: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class RouteChangeCreate(BaseModel):
    route_id: int
    customer_id: int | None = None
    change_type: Literal["add_stop", "remove_stop", "reorder", "edit_stop"]
    recommended_sequence: int | None = Field(default=None, ge=1)
    additional_distance_km: float = Field(default=0, ge=0)
    additional_time_mins: float = Field(default=0, ge=0)
    reason: str | None = None


class RegisterRequest(BaseModel):
    email: str
    password: str = Field(min_length=8, max_length=72)
    role: Literal["operator", "driver"] = "operator"


class ProfileUpdate(BaseModel):
    email: str | None = None
    current_password: str | None = None
    new_password: str | None = Field(default=None, min_length=8, max_length=72)

class CommandRequest(BaseModel):
    command: Literal["START_JOURNEY", "PAUSE_JOURNEY", "RESUME_JOURNEY", "STOP_JOURNEY", "ASSIGN_PERSON", "UNASSIGN_PERSON", "ASSIGN_VEHICLE", "SET_DESTINATION", "CREATE_LOCATION", "RESOLVE_ALERT", "ENABLE_AUTOMATION", "DISABLE_AUTOMATION", "REFRESH_STATE"]
    payload: dict[str, Any] = Field(default_factory=dict)

class EventOut(BaseModel):
    id: int; event_type: str; entity_type: str; entity_id: int | None; timestamp: datetime; source: str; payload: dict[str, Any]
    model_config = ConfigDict(from_attributes=True)

class AlertOut(BaseModel):
    id: int; severity: str; alert_type: str; entity_type: str; entity_id: int | None; message: str; status: str; created_at: datetime; resolved_at: datetime | None; payload: dict[str, Any]
    model_config = ConfigDict(from_attributes=True)
