import sys
import os
import tempfile
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

# Tests must never depend on or mutate the developer's imported demo database.
# Configure the database before application modules are imported, then seed a
# clean operational fixture for every test run.
_test_db = tempfile.NamedTemporaryFile(prefix="routeos-test-", suffix=".db", delete=False)
_test_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_test_db.name}"
os.environ["SEED_DEMO_DATA"] = "false"
from database import SessionLocal, init_db
from seed import seed, seed_product_demo

init_db()
with SessionLocal() as _db:
    seed(_db)
    seed_product_demo(_db)
