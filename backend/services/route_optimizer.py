"""
Route Optimizer Service
=======================
Uses OSRM (Open Source Routing Machine) for real road network distances
with automatic fallback to Haversine straight-line if OSRM is unavailable.

OSRM public API: http://router.project-osrm.org
For production, host your own OSRM instance or use Mapbox Matrix API.
"""

import math
import logging
import urllib.request
import urllib.error
import json
from typing import List, Optional, Tuple
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────────────────────
OSRM_BASE_URL = "http://router.project-osrm.org"
OSRM_TIMEOUT_SECS = 5  # seconds — fail fast and fall back to Haversine
AVG_URBAN_SPEED_KMH = 25.0  # Kozhikode urban road average


# ── Data Structures ──────────────────────────────────────────────────────────

@dataclass
class StopPoint:
    stop_id: int
    name: str
    latitude: float
    longitude: float
    sequence: int


@dataclass
class InsertionOption:
    position: int              # Insert BEFORE this 1-based sequence index
    after_stop_name: Optional[str]
    before_stop_name: Optional[str]
    additional_distance_km: float
    additional_time_mins: float
    is_recommended: bool = False
    used_real_roads: bool = False   # True = OSRM, False = Haversine fallback


# ── Distance Helpers ──────────────────────────────────────────────────────────

def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in km between two lat/lng points."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def estimate_travel_time_mins(distance_km: float, avg_speed_kmh: float = AVG_URBAN_SPEED_KMH) -> float:
    """Estimate travel time from distance at given average speed."""
    if avg_speed_kmh <= 0:
        return 0.0
    return (distance_km / avg_speed_kmh) * 60


def _build_osrm_coords(points: List[Tuple[float, float]]) -> str:
    """Build OSRM coordinate string: 'lng,lat;lng,lat;...'"""
    return ";".join(f"{lng},{lat}" for lat, lng in points)


def fetch_osrm_table(points: List[Tuple[float, float]]) -> Optional[List[List[float]]]:
    """
    Fetch an N×N driving distance matrix from OSRM Table API.
    Returns durations in seconds (upper triangle usable for symmetric routing).
    Returns None if request fails.
    """
    if len(points) < 2:
        return None
    coords = _build_osrm_coords(points)
    url = f"{OSRM_BASE_URL}/table/v1/driving/{coords}?annotations=distance,duration"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "RouteApp/1.0"})
        with urllib.request.urlopen(req, timeout=OSRM_TIMEOUT_SECS) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        if data.get("code") != "Ok":
            logger.warning("OSRM returned non-Ok code: %s", data.get("code"))
            return None
        # distances in metres
        return data.get("distances")
    except (urllib.error.URLError, TimeoutError, Exception) as exc:
        logger.warning("OSRM unavailable (%s). Falling back to Haversine.", exc)
        return None


def road_distance_km(
    lat1: float, lon1: float,
    lat2: float, lon2: float,
    matrix: Optional[List[List[float]]] = None,
    i: int = 0,
    j: int = 1,
) -> Tuple[float, bool]:
    """
    Return (distance_km, used_real_roads).
    Prefers OSRM matrix value; falls back to Haversine.
    """
    if matrix is not None:
        try:
            dist_m = matrix[i][j]
            if dist_m is not None and dist_m >= 0:
                return round(dist_m / 1000, 3), True
        except (IndexError, TypeError):
            pass
    return round(haversine_km(lat1, lon1, lat2, lon2), 3), False


# ── Core Cheapest-Insertion Algorithm ────────────────────────────────────────

def find_best_insertion(
    stops: List[StopPoint],
    new_lat: float,
    new_lng: float,
    new_name: str,
    depot_lat: float,
    depot_lng: float,
    depot_name: str = "Warehouse",
) -> Tuple[int, List[InsertionOption]]:
    """
    Cheapest-insertion algorithm using real road distances (OSRM) with Haversine fallback.

    Route model: Depot → S1 → S2 → ... → Sn → Depot
    Cost of inserting X between (prev, next):
        delta = dist(prev→X) + dist(X→next) - dist(prev→next)

    Returns: (recommended_position, all_options_sorted_by_cost)
    """
    if not stops:
        add_dist = haversine_km(depot_lat, depot_lng, new_lat, new_lng) * 2
        option = InsertionOption(
            position=1,
            after_stop_name=depot_name,
            before_stop_name=depot_name,
            additional_distance_km=round(add_dist, 3),
            additional_time_mins=round(estimate_travel_time_mins(add_dist), 1),
            is_recommended=True,
        )
        return 1, [option]

    # Build point list: depot + stops + depot
    all_coords: List[Tuple[float, float]] = (
        [(depot_lat, depot_lng)]
        + [(s.latitude, s.longitude) for s in stops]
        + [(depot_lat, depot_lng)]
    )
    all_names = [depot_name] + [s.name for s in stops] + [depot_name]

    # New stop coordinates
    new_coord = (new_lat, new_lng)

    # Try to fetch OSRM distance matrix for all relevant points
    # We need distances between every consecutive pair plus to/from new stop
    matrix_points = all_coords + [new_coord]
    new_idx = len(matrix_points) - 1
    osrm_matrix = fetch_osrm_table(matrix_points)

    options: List[InsertionOption] = []
    real_roads_used = False

    for i in range(len(all_coords) - 1):
        prev_lat, prev_lng = all_coords[i]
        next_lat, next_lng = all_coords[i + 1]
        prev_name = all_names[i]
        next_name = all_names[i + 1]

        if osrm_matrix:
            d_prev_new, rr1 = road_distance_km(prev_lat, prev_lng, new_lat, new_lng, osrm_matrix, i, new_idx)
            d_new_next, rr2 = road_distance_km(new_lat, new_lng, next_lat, next_lng, osrm_matrix, new_idx, i + 1)
            d_prev_next, rr3 = road_distance_km(prev_lat, prev_lng, next_lat, next_lng, osrm_matrix, i, i + 1)
            real_roads = rr1 and rr2 and rr3
        else:
            d_prev_new = haversine_km(prev_lat, prev_lng, new_lat, new_lng)
            d_new_next = haversine_km(new_lat, new_lng, next_lat, next_lng)
            d_prev_next = haversine_km(prev_lat, prev_lng, next_lat, next_lng)
            real_roads = False

        if real_roads:
            real_roads_used = True

        additional = max(0.0, d_prev_new + d_new_next - d_prev_next)
        position = i + 1  # Insert at sequence position i+1

        options.append(InsertionOption(
            position=position,
            after_stop_name=prev_name if i > 0 else None,
            before_stop_name=next_name if i < len(all_coords) - 2 else None,
            additional_distance_km=round(additional, 3),
            additional_time_mins=round(estimate_travel_time_mins(additional), 1),
            used_real_roads=real_roads,
        ))

    options.sort(key=lambda o: o.additional_distance_km)

    if options:
        options[0].is_recommended = True

    recommended_position = options[0].position if options else 1

    if real_roads_used:
        logger.info("Route insertion computed using OSRM road network distances.")
    else:
        logger.info("Route insertion computed using Haversine fallback (OSRM unavailable).")

    return recommended_position, options
