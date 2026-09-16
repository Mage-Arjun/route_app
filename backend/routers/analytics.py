from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, Float, cast
from database import get_db
from auth import get_current_user, get_admin_user
import models, schemas

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/dashboard", response_model=schemas.DashboardStats)
def get_dashboard(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    today = date.today()

    total_routes = db.query(models.Route).filter(models.Route.status == "active").count()
    active_routes = db.query(models.Trip).filter(
        models.Trip.status == "active",
        models.Trip.date == today
    ).count()
    total_customers = db.query(models.Customer).filter(models.Customer.status == "active").count()
    total_vehicles = db.query(models.Vehicle).filter(models.Vehicle.status == "active").count()
    total_drivers = db.query(models.User).filter(
        models.User.role == "driver",
        models.User.status == "active"
    ).count()

    today_trips = db.query(models.Trip).filter(models.Trip.date == today).count()

    today_completed = db.query(func.sum(models.Trip.completed_stops)).filter(
        models.Trip.date == today
    ).scalar() or 0

    today_pending_q = db.query(models.TripStop).join(models.Trip).filter(
        models.Trip.date == today,
        models.TripStop.status == "pending"
    ).count()

    pending_approvals = db.query(models.RouteChange).filter(
        models.RouteChange.status == "pending"
    ).count()

    return schemas.DashboardStats(
        total_routes=total_routes,
        active_routes=active_routes,
        total_customers=total_customers,
        total_vehicles=total_vehicles,
        total_drivers=total_drivers,
        today_trips=today_trips,
        today_completed_stops=int(today_completed),
        today_pending_stops=today_pending_q,
        pending_approvals=pending_approvals,
    )


@router.get("/routes/{route_id}", response_model=schemas.RouteAnalytics)
def route_analytics(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    trips = db.query(models.Trip).options(
        joinedload(models.Trip.driver),
        joinedload(models.Trip.vehicle),
        joinedload(models.Trip.route),
        joinedload(models.Trip.trip_stops).joinedload(models.TripStop.customer),
    ).filter(models.Trip.route_id == route_id).order_by(models.Trip.date.desc()).limit(10).all()

    total_trips = db.query(models.Trip).filter(models.Trip.route_id == route_id).count()

    avg_completion = 0.0
    avg_distance = 0.0
    if total_trips > 0:
        from sqlalchemy import case
        completed_data = db.query(
            func.avg(
                cast(models.Trip.completed_stops, Float) /
                cast(
                    case((models.Trip.total_stops == 0, 1), else_=models.Trip.total_stops),
                    Float
                )
            )
        ).filter(models.Trip.route_id == route_id).scalar()
        avg_completion = float(completed_data or 0) * 100

        dist_data = db.query(func.avg(models.Trip.total_distance_km)).filter(
            models.Trip.route_id == route_id
        ).scalar()
        avg_distance = float(dist_data or 0)

    total_stops = db.query(models.RouteStop).filter(
        models.RouteStop.route_id == route_id,
        models.RouteStop.status == "active"
    ).count()

    return schemas.RouteAnalytics(
        route_id=route_id,
        route_name=route.name,
        total_trips=total_trips,
        avg_completion_rate=round(avg_completion, 1),
        avg_distance_km=round(avg_distance, 2),
        total_stops=total_stops,
        recent_trips=trips,
    )
