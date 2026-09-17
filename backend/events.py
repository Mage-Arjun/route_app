import logging
from datetime import datetime, timezone
from typing import Awaitable, Callable
from sqlalchemy.orm import Session
from models import Event

log = logging.getLogger("routeos.event")
Subscriber = Callable[[dict], Awaitable[None]]

class EventEngine:
    def __init__(self):
        self.subscribers: set[Subscriber] = set()
        self.last_event_at: datetime | None = None
        self.enabled = True

    def subscribe(self, callback: Subscriber) -> None: self.subscribers.add(callback)
    def unsubscribe(self, callback: Subscriber) -> None: self.subscribers.discard(callback)

    async def publish(self, db: Session, *, event_type: str, entity_type: str, entity_id: int | None = None,
                      payload: dict | None = None, actor_id: int | None = None, source: str = "system",
                      location_id: int | None = None) -> Event:
        event = Event(event_type=event_type, entity_type=entity_type, entity_id=entity_id,
                      payload=payload or {}, actor_id=actor_id, source=source, timestamp=datetime.now(timezone.utc))
        db.add(event); db.commit(); db.refresh(event)
        self.last_event_at = event.timestamp
        message = {"type": "event", "event_type": event.event_type, "entity_type": event.entity_type,
                   "entity_id": event.entity_id, "timestamp": event.timestamp.isoformat(), "payload": event.payload}
        log.info("%s %s/%s", event.event_type, entity_type, entity_id)
        for subscriber in tuple(self.subscribers):
            try: await subscriber(message)
            except Exception: log.exception("event subscriber failed")
        return event

    async def broadcast(self, message: dict) -> None:
        """Broadcast a non-event state/control message to connected clients."""
        for subscriber in tuple(self.subscribers):
            try:
                await subscriber(message)
            except Exception:
                log.exception("event subscriber failed")

event_engine = EventEngine()
