import json
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from database import get_db
from auth import get_current_user, get_admin_user
import models, schemas
from typing import List, Optional
from services.route_optimizer import find_best_insertion, StopPoint

router = APIRouter(prefix="/routes", tags=["routes"])


def _snapshot_stops(stops: List[models.RouteStop]) -> str:
    return json.dumps([{
        "sequence": s.sequence,
        "customer_id": s.customer_id,
        "customer_name": s.customer.name if s.customer else None,
    } for s in stops])


def _save_version(db: Session, route: models.Route, summary: str, changed_by_id: int):
    route.version += 1
    db.flush()
    version = models.RouteVersion(
        route_id=route.id,
        version=route.version,
        snapshot=_snapshot_stops(route.stops),
        change_summary=summary,
        changed_by_id=changed_by_id,
    )
    db.add(version)


# ─── Routes CRUD ─────────────────────────────────────────

@router.get("/", response_model=List[schemas.RouteOut])
def list_routes(
    status: Optional[str] = Query(None),
    driver_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    q = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer),
        joinedload(models.Route.assigned_driver),
        joinedload(models.Route.assigned_vehicle).joinedload(models.Vehicle.assigned_driver),
    )
    if current_user.role == "driver":
        q = q.filter(models.Route.assigned_driver_id == current_user.id)
    if driver_id:
        q = q.filter(models.Route.assigned_driver_id == driver_id)
    if status:
        q = q.filter(models.Route.status == status)
    else:
        q = q.filter(models.Route.status == "active")
    return q.order_by(models.Route.name).offset(skip).limit(limit).all()


@router.post("/", response_model=schemas.RouteOut)
def create_route(
    route_in: schemas.RouteCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route_data = route_in.model_dump()
    if current_user.role == "driver":
        route_data["assigned_driver_id"] = current_user.id
    route = models.Route(**route_data)
    db.add(route)
    db.flush()
    version = models.RouteVersion(
        route_id=route.id,
        version=1,
        snapshot="[]",
        change_summary="Route created",
        changed_by_id=current_user.id,
    )
    db.add(version)
    db.commit()
    db.refresh(route)
    return route



@router.get("/{route_id}", response_model=schemas.RouteOut)
def get_route(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer),
        joinedload(models.Route.assigned_driver),
        joinedload(models.Route.assigned_vehicle).joinedload(models.Vehicle.assigned_driver),
    ).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    return route


@router.put("/{route_id}", response_model=schemas.RouteOut)
def update_route(
    route_id: int,
    route_in: schemas.RouteUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin_user)
):
    route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    for field, value in route_in.model_dump(exclude_unset=True).items():
        setattr(route, field, value)
    db.commit()
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer),
        joinedload(models.Route.assigned_driver),
        joinedload(models.Route.assigned_vehicle).joinedload(models.Vehicle.assigned_driver),
    ).filter(models.Route.id == route_id).first()
    return route


# ─── Route Stops ─────────────────────────────────────────

@router.post("/{route_id}/stops", response_model=schemas.RouteOut)
def add_stop(
    route_id: int,
    stop_in: schemas.RouteStopCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    customer = db.query(models.Customer).filter(models.Customer.id == stop_in.customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    active_stops = [s for s in route.stops if s.status == "active"]

    if stop_in.sequence is not None:
        insert_seq = stop_in.sequence
    else:
        # Use smart insertion
        stop_points = [StopPoint(
            stop_id=s.id,
            name=s.customer.name,
            latitude=s.customer.latitude,
            longitude=s.customer.longitude,
            sequence=s.sequence,
        ) for s in sorted(active_stops, key=lambda x: x.sequence)]

        depot_lat = route.start_lat or 11.2588
        depot_lng = route.start_lng or 75.7804

        recommended, _ = find_best_insertion(
            stops=stop_points,
            new_lat=customer.latitude,
            new_lng=customer.longitude,
            new_name=customer.name,
            depot_lat=depot_lat,
            depot_lng=depot_lng,
        )
        insert_seq = recommended

    # Shift existing stops
    for s in active_stops:
        if s.sequence >= insert_seq:
            s.sequence += 1

    new_stop = models.RouteStop(
        route_id=route_id,
        customer_id=stop_in.customer_id,
        sequence=insert_seq,
        planned_arrival_time=stop_in.planned_arrival_time,
        service_duration_mins=stop_in.service_duration_mins,
        notes=stop_in.notes,
    )
    db.add(new_stop)
    db.flush()
    db.refresh(route)

    _save_version(db, route, f"Added {customer.name} at position {insert_seq}", current_user.id)
    db.commit()
    db.refresh(route)
    return route


@router.post("/{route_id}/stops/quick-add", response_model=schemas.RouteOut)
def quick_add_stop(
    route_id: int,
    stop_in: schemas.QuickStopCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    customer = models.Customer(
        name=stop_in.name,
        latitude=stop_in.latitude,
        longitude=stop_in.longitude,
        address=stop_in.address or f"Lat: {stop_in.latitude:.5f}, Lng: {stop_in.longitude:.5f}",
        phone=stop_in.phone,
        notes=stop_in.notes,
        created_by_id=current_user.id,
    )
    db.add(customer)
    db.flush()

    active_stops = [s for s in route.stops if s.status == "active"]

    if stop_in.sequence is not None:
        insert_seq = stop_in.sequence
    else:
        stop_points = [StopPoint(
            stop_id=s.id,
            name=s.customer.name,
            latitude=s.customer.latitude,
            longitude=s.customer.longitude,
            sequence=s.sequence,
        ) for s in sorted(active_stops, key=lambda x: x.sequence)]

        depot_lat = route.start_lat or 11.2588
        depot_lng = route.start_lng or 75.7804

        recommended, _ = find_best_insertion(
            stops=stop_points,
            new_lat=customer.latitude,
            new_lng=customer.longitude,
            new_name=customer.name,
            depot_lat=depot_lat,
            depot_lng=depot_lng,
        )
        insert_seq = recommended

    for s in active_stops:
        if s.sequence >= insert_seq:
            s.sequence += 1

    new_stop = models.RouteStop(
        route_id=route_id,
        customer_id=customer.id,
        sequence=insert_seq,
        service_duration_mins=stop_in.service_duration_mins,
        notes=stop_in.notes,
    )
    db.add(new_stop)
    db.flush()

    # Also sync into any currently active trip so driver's screen updates immediately
    active_trip = db.query(models.Trip).filter(
        models.Trip.route_id == route_id,
        models.Trip.driver_id == current_user.id,
        models.Trip.status == "active",
    ).first()
    if active_trip:
        for ts in active_trip.trip_stops:
            if ts.sequence >= insert_seq:
                ts.sequence += 1
        new_ts = models.TripStop(
            trip_id=active_trip.id,
            route_stop_id=new_stop.id,
            customer_id=customer.id,
            sequence=insert_seq,
        )
        db.add(new_ts)
        active_trip.total_stops += 1

    _save_version(db, route, f"Driver added {customer.name} (GPS) at stop #{insert_seq}", current_user.id)
    db.commit()


    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer),
        joinedload(models.Route.assigned_driver),
        joinedload(models.Route.assigned_vehicle),
    ).filter(models.Route.id == route_id).first()
    return route



@router.put("/{route_id}/stops/reorder", response_model=schemas.RouteOut)
def reorder_stops(
    route_id: int,
    reorder: schemas.StopReorderRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    stop_map = {s.id: s for s in route.stops}
    for new_seq, stop_id in enumerate(reorder.stop_ids, start=1):
        if stop_id in stop_map:
            stop_map[stop_id].sequence = new_seq

    _save_version(db, route, "Stops reordered", current_user.id)
    db.commit()
    db.refresh(route)
    return route


@router.delete("/{route_id}/stops/{stop_id}", response_model=schemas.RouteOut)
def remove_stop(
    route_id: int,
    stop_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    stop = db.query(models.RouteStop).filter(
        models.RouteStop.id == stop_id,
        models.RouteStop.route_id == route_id
    ).first()
    if not stop:
        raise HTTPException(status_code=404, detail="Stop not found")

    removed_seq = stop.sequence
    stop.status = "removed"

    # Re-sequence remaining
    active_stops = sorted(
        [s for s in route.stops if s.status == "active" and s.id != stop_id],
        key=lambda x: x.sequence
    )
    for i, s in enumerate(active_stops, start=1):
        s.sequence = i

    customer_name = stop.customer.name if stop.customer else "unknown"
    _save_version(db, route, f"Removed {customer_name}", current_user.id)
    db.commit()
    db.refresh(route)
    return route


# ─── Smart Insertion Preview ──────────────────────────────

@router.post("/{route_id}/calculate-insertion", response_model=schemas.InsertionResult)
def calculate_insertion(
    route_id: int,
    stop_in: schemas.RouteStopCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    customer = db.query(models.Customer).filter(models.Customer.id == stop_in.customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    active_stops = sorted(
        [s for s in route.stops if s.status == "active"],
        key=lambda x: x.sequence
    )
    stop_points = [StopPoint(
        stop_id=s.id,
        name=s.customer.name,
        latitude=s.customer.latitude,
        longitude=s.customer.longitude,
        sequence=s.sequence,
    ) for s in active_stops]

    depot_lat = route.start_lat or 11.2588
    depot_lng = route.start_lng or 75.7804

    recommended_pos, options = find_best_insertion(
        stops=stop_points,
        new_lat=customer.latitude,
        new_lng=customer.longitude,
        new_name=customer.name,
        depot_lat=depot_lat,
        depot_lng=depot_lng,
    )

    return schemas.InsertionResult(
        customer_id=customer.id,
        customer_name=customer.name,
        recommended_position=recommended_pos,
        options=[
            schemas.InsertionOption(
                position=o.position,
                after_stop_name=o.after_stop_name,
                before_stop_name=o.before_stop_name,
                additional_distance_km=o.additional_distance_km,
                additional_time_mins=o.additional_time_mins,
                is_recommended=o.is_recommended,
            )
            for o in options
        ]
    )


# ─── Route Versions ──────────────────────────────────────

@router.get("/{route_id}/versions", response_model=List[schemas.RouteVersionOut])
def get_versions(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    versions = db.query(models.RouteVersion).options(
        joinedload(models.RouteVersion.changed_by)
    ).filter(
        models.RouteVersion.route_id == route_id
    ).order_by(models.RouteVersion.version.desc()).all()
    return versions


# ─── Route Changes (Approval workflow) ───────────────────

@router.get("/changes/", response_model=List[schemas.RouteChangeOut])
def list_all_changes(
    status: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin_user)
):
    q = db.query(models.RouteChange).options(
        joinedload(models.RouteChange.customer),
        joinedload(models.RouteChange.route),
        joinedload(models.RouteChange.requested_by),
        joinedload(models.RouteChange.approved_by),
    )
    if status:
        q = q.filter(models.RouteChange.status == status)
    return q.order_by(models.RouteChange.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/changes/mine", response_model=List[schemas.RouteChangeOut])
def list_my_changes(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    return db.query(models.RouteChange).filter(
        models.RouteChange.requested_by_id == current_user.id
    ).options(
        joinedload(models.RouteChange.customer),
        joinedload(models.RouteChange.route),
        joinedload(models.RouteChange.requested_by),
        joinedload(models.RouteChange.approved_by),
    ).order_by(models.RouteChange.created_at.desc()).all()


@router.get("/changes/pending", response_model=List[schemas.RouteChangeOut])
def list_pending_changes(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin_user)
):
    return db.query(models.RouteChange).filter(
        models.RouteChange.status == "pending"
    ).options(
        joinedload(models.RouteChange.customer),
        joinedload(models.RouteChange.route),
        joinedload(models.RouteChange.requested_by),
        joinedload(models.RouteChange.approved_by),
    ).all()


@router.post("/changes/", response_model=schemas.RouteChangeOut)
def submit_change(
    change_in: schemas.RouteChangeCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    existing = db.query(models.RouteChange).filter(
        models.RouteChange.route_id == change_in.route_id,
        models.RouteChange.customer_id == change_in.customer_id,
        models.RouteChange.status == "pending",
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="A pending change for this customer on this route already exists")

    change = models.RouteChange(
        route_id=change_in.route_id,
        customer_id=change_in.customer_id,
        recommended_sequence=change_in.recommended_sequence,
        additional_distance_km=change_in.additional_distance_km,
        additional_time_mins=change_in.additional_time_mins,
        requested_by_id=current_user.id,
    )
    db.add(change)
    db.commit()
    db.refresh(change)
    change = db.query(models.RouteChange).options(
        joinedload(models.RouteChange.customer),
        joinedload(models.RouteChange.route),
        joinedload(models.RouteChange.requested_by),
        joinedload(models.RouteChange.approved_by),
    ).filter(models.RouteChange.id == change.id).first()
    return change


@router.put("/changes/{change_id}/approve")
def approve_change(
    change_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin_user)
):
    change = db.query(models.RouteChange).filter(models.RouteChange.id == change_id).first()
    if not change:
        raise HTTPException(status_code=404, detail="Change not found")
    if change.status != "pending":
        raise HTTPException(status_code=400, detail="Change is not pending")

    existing_stop = db.query(models.RouteStop).filter(
        models.RouteStop.route_id == change.route_id,
        models.RouteStop.customer_id == change.customer_id,
        models.RouteStop.status == "active",
    ).first()
    if existing_stop:
        raise HTTPException(status_code=400, detail="Customer is already an active stop on this route")

    change.status = "approved"
    change.approved_by_id = current_user.id
    change.updated_at = datetime.now(timezone.utc)

    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == change.route_id).first()

    if route:
        active_stops = [s for s in route.stops if s.status == "active"]
        insert_seq = change.recommended_sequence
        for s in active_stops:
            if s.sequence >= insert_seq:
                s.sequence += 1
        customer = db.query(models.Customer).filter(models.Customer.id == change.customer_id).first()
        new_stop = models.RouteStop(
            route_id=change.route_id,
            customer_id=change.customer_id,
            sequence=insert_seq,
        )
        db.add(new_stop)
        db.flush()
        db.refresh(route)
        _save_version(db, route, f"Approved: Added {customer.name if customer else ''}", current_user.id)

    db.commit()
    return {"message": "Change approved and applied"}


@router.put("/changes/{change_id}/reject")
def reject_change(
    change_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin_user)
):
    change = db.query(models.RouteChange).filter(models.RouteChange.id == change_id).first()
    if not change:
        raise HTTPException(status_code=404, detail="Change not found")
    change.status = "rejected"
    change.approved_by_id = current_user.id
    change.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Change rejected"}
