import asyncio
import httpx
import websockets
from config import settings

class BackendClient:
    def __init__(self, base_url: str | None = None): self.base_url = (base_url or settings.TUI_BACKEND_URL).rstrip("/"); self.token = None
    async def get(self, path: str):
        async with httpx.AsyncClient(base_url=self.base_url, timeout=3) as client:
            response = await client.get(path, headers={"Authorization": f"Bearer {self.token}"} if self.token else {}); response.raise_for_status(); return response.json()
    async def login(self):
        async with httpx.AsyncClient(base_url=self.base_url, timeout=3) as client:
            response = await client.post("/auth/login", json={"email": settings.TUI_EMAIL, "password": settings.TUI_PASSWORD}); response.raise_for_status(); self.token = response.json()["access_token"]
    async def status(self): return await self.get("/system/status")
    async def network(self): return await self.get("/system/network")
    async def command(self, name: str, payload: dict | None = None):
        async with httpx.AsyncClient(base_url=self.base_url, timeout=3) as client:
            response = await client.post("/commands", json={"command": name, "payload": payload or {}}, headers={"Authorization": f"Bearer {self.token}"})
            response.raise_for_status()
            return response.json()
    async def dashboard(self): return {"people": await self.get("/people"), "vehicles": await self.get("/vehicles"), "journeys": await self.get("/journeys"), "alerts": await self.get("/alerts")}
    async def listen(self):
        ws_url = self.base_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws"
        async with websockets.connect(
            ws_url,
            open_timeout=3,
            additional_headers={"Authorization": f"Bearer {self.token}"},
        ) as socket:
            await socket.recv()
            async for message in socket: yield message
