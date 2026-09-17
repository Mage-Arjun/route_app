from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from config import settings
from events import event_engine
from models import Alert, Journey, Person, Vehicle


class AutomationEngine:
    def __init__(self):
        self.enabled = settings.AUTOMATION_ENABLED

    async def evaluate_vehicle(self, db: Session, vehicle: Vehicle):
        if not self.enabled or not vehicle.last_seen:
            return None
        last_seen = vehicle.last_seen
        if last_seen.tzinfo is None:
            last_seen = last_seen.replace(tzinfo=timezone.utc)
        stale_at = datetime.now(timezone.utc) - timedelta(seconds=settings.GPS_STALE_THRESHOLD)
        if last_seen >= stale_at:
            return None
        existing = (
            db.query(Alert)
            .filter(
                Alert.alert_type == "GPS_STALE",
                Alert.entity_type == "vehicle",
                Alert.entity_id == vehicle.id,
                Alert.status == "active",
            )
            .first()
        )
        if existing:
            return existing
        alert = Alert(
            severity="warning",
            alert_type="GPS_STALE",
            entity_type="vehicle",
            entity_id=vehicle.id,
            message=f"{vehicle.identifier} has stale GPS data",
            payload={"last_seen": vehicle.last_seen.isoformat()},
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)
        await event_engine.publish(
            db,
            event_type="ALERT_CREATED",
            entity_type="alert",
            entity_id=alert.id,
            payload={"alert_id": alert.id, "alert_type": alert.alert_type, "vehicle_id": vehicle.id},
            source="automation",
        )
        return alert

    async def _active_alert(self, db: Session, *, alert_type: str, entity_type: str, entity_id: int, severity: str, message: str, payload: dict):
        existing = db.query(Alert).filter(Alert.alert_type == alert_type, Alert.entity_type == entity_type, Alert.entity_id == entity_id, Alert.status == "active").first()
        if existing:
            return existing
        alert = Alert(severity=severity, alert_type=alert_type, entity_type=entity_type, entity_id=entity_id, message=message, payload=payload)
        db.add(alert); db.commit(); db.refresh(alert)
        await event_engine.publish(db, event_type="ALERT_CREATED", entity_type="alert", entity_id=alert.id, payload={"alert_id": alert.id, "alert_type": alert_type, **payload}, source="automation")
        return alert

    async def evaluate_unexpected_exit(self, db: Session, person: Person, *, vehicle_id: int | None, journey_id: int | None):
        if not self.enabled or not journey_id:
            return None
        journey = db.get(Journey, journey_id)
        if not journey or journey.status not in {"active", "paused", "arrived"}:
            return None
        return await self._active_alert(db, alert_type="UNEXPECTED_EXIT", entity_type="person", entity_id=person.id, severity="warning", message=f"{person.identifier} exited journey {journey.identifier} unexpectedly", payload={"vehicle_id": vehicle_id, "journey_id": journey_id})

    async def evaluate_journey(self, db: Session, journey: Journey):
        if not self.enabled or journey.status not in {"active", "paused", "arrived"} or journey.destination_location_id:
            return None
        return await self._active_alert(db, alert_type="MISSING_DESTINATION", entity_type="journey", entity_id=journey.id, severity="warning", message=f"{journey.identifier} has no destination", payload={"journey_id": journey.id})

    async def evaluate_all(self, db: Session):
        if not self.enabled:
            return []
        created = []
        for vehicle in db.query(Vehicle).all():
            alert = await self.evaluate_vehicle(db, vehicle)
            if alert:
                created.append(alert)
        for journey in db.query(Journey).all():
            alert = await self.evaluate_journey(db, journey)
            if alert:
                created.append(alert)
        return created


automation_engine = AutomationEngine()
