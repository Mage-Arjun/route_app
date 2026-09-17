from datetime import datetime, timedelta, timezone
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
import bcrypt
from sqlalchemy.orm import Session
from config import settings
from database import get_db
from models import User

oauth2 = OAuth2PasswordBearer(tokenUrl="/auth/login")

def hash_password(value: str) -> str:
    if len(value.encode("utf-8")) > 72: raise ValueError("Password must be 72 bytes or shorter")
    return bcrypt.hashpw(value.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def verify_password(value: str, hashed: str) -> bool:
    try: return bcrypt.checkpw(value.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError): return False

def create_token(user: User) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({"sub": str(user.id), "role": user.role, "exp": exp}, settings.SECRET_KEY, algorithm="HS256")

def authenticate_token(token: str, db: Session) -> User:
    credentials = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication credentials")
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = int(payload.get("sub", ""))
    except (JWTError, ValueError, TypeError):
        raise credentials
    user = db.get(User, user_id)
    if not user or user.status != "active":
        raise credentials
    return user


def current_user(token: str = Depends(oauth2), db: Session = Depends(get_db)) -> User:
    return authenticate_token(token, db)

def require_operator(user: User = Depends(current_user)) -> User:
    if user.role not in {"admin", "operator"}: raise HTTPException(status_code=403, detail="Operator role required")
    return user

def require_admin(user: User = Depends(current_user)) -> User:
    if user.role != "admin": raise HTTPException(status_code=403, detail="Admin role required")
    return user

def require_driver(user: User = Depends(current_user)) -> User:
    if user.role != "driver": raise HTTPException(status_code=403, detail="Driver role required")
    return user
