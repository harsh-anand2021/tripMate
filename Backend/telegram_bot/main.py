import os
import logging
import base64
import math
import io
import random
import time
import requests
from sqlalchemy import ForeignKey, Column, String, Integer, DateTime, LargeBinary
from sqlalchemy.orm import relationship, sessionmaker
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import numpy as np
from PIL import Image
from insightface.app import FaceAnalysis
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.future import select

# Load environment variables
load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
DATABASE_URL = os.getenv("DATABASE_URL")

if not TELEGRAM_BOT_TOKEN or not DATABASE_URL:
    raise ValueError("Environment variables TELEGRAM_BOT_TOKEN or DATABASE_URL missing")

# FastAPI app setup
app = FastAPI()
logger = logging.getLogger("uvicorn")
logger.setLevel(logging.INFO)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# DB setup
Base = declarative_base()

class UserSelfie(Base):
    __tablename__ = "user_selfies"
    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), nullable=False)
    selfie = Column(LargeBinary, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class TripDetail(Base):
    __tablename__ = "trip_details"
    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), nullable=False)
    trip_number = Column(Integer, nullable=False)
    checkin_time = Column(DateTime(timezone=True), server_default=func.now())

engine = create_async_engine(DATABASE_URL, echo=True)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

otp_store = {}
OTP_EXPIRY_SECONDS = 300  # 5 minutes

@app.on_event("startup")
async def on_startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    global face_app
    face_app = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
    face_app.prepare(ctx_id=0)
    logger.info("FaceAnalysis model loaded on startup")

class OTPRequest(BaseModel):
    phone: str
    chat_id: str

class OTPVerify(BaseModel):
    phone: str
    otp: str

@app.post("/send_otp")
def send_otp(data: OTPRequest):
    otp = f"{random.randint(100000, 999999)}"
    timestamp = time.time()
    otp_store[data.phone] = {"otp": otp, "timestamp": timestamp}

    message = f"Your TripMate OTP is: {otp}"
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": data.chat_id,
        "text": message
    }
    response = requests.post(url, json=payload)

    if response.status_code == 200:
        return {"success": True, "message": "OTP sent"}
    else:
        raise HTTPException(status_code=500, detail="Failed to send OTP")

@app.post("/verify_otp")
def verify_otp(data: OTPVerify):
    record = otp_store.get(data.phone)
    if not record:
        return {"success": False, "message": "No OTP found"}

    if time.time() - record["timestamp"] > OTP_EXPIRY_SECONDS:
        otp_store.pop(data.phone, None)
        return {"success": False, "message": "OTP expired"}

    if data.otp == record["otp"]:
        otp_store.pop(data.phone, None)
        return {"success": True}
    else:
        return {"success": False, "message": "Invalid OTP"}

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

@app.post("/checkin")
async def checkin(
    phone_number: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    selfie: UploadFile = File(...)
):
    try:
        ALLOWED_LAT, ALLOWED_LON = 13.0179, 80.2533
        MAX_DISTANCE_METERS = 50000

        dist = haversine(latitude, longitude, ALLOWED_LAT, ALLOWED_LON)
        logger.info(f"User distance: {dist} meters")
        if dist > MAX_DISTANCE_METERS:
            return {"success": False, "result": "location_invalid", "message": "Outside allowed geofence"}

        uploaded_bytes = await selfie.read()
        uploaded_image = Image.open(io.BytesIO(uploaded_bytes)).convert("RGB")
        uploaded_np = np.array(uploaded_image)

        faces_uploaded = face_app.get(uploaded_np)
        if not faces_uploaded:
            return {"success": False, "result": "face_mismatch", "message": "No face detected in uploaded selfie"}

        async with async_session() as session:
            result = await session.execute(
                select(UserSelfie).where(UserSelfie.phone_number == phone_number).order_by(UserSelfie.created_at.desc()).limit(1)
            )
            stored = result.scalar_one_or_none()
            if not stored:
                return {"success": False, "result": "face_mismatch", "message": "No stored selfie found"}

            stored_image = Image.open(io.BytesIO(stored.selfie)).convert("RGB")
            stored_np = np.array(stored_image)
            faces_stored = face_app.get(stored_np)
            if not faces_stored:
                return {"success": False, "result": "face_mismatch", "message": "No face detected in stored selfie"}

            emb_uploaded = faces_uploaded[0].embedding
            emb_stored = faces_stored[0].embedding
            similarity = np.dot(emb_uploaded, emb_stored) / (np.linalg.norm(emb_uploaded) * np.linalg.norm(emb_stored))

            if similarity >= 0.75:
                trip_number = random.randint(1, 20)
                new_trip = TripDetail(phone_number=phone_number, trip_number=trip_number)
                session.add(new_trip)
                await session.commit()

                return {
                    "success": True,
                    "result": "success",
                    "message": f"Check-in successful for {phone_number}",
                    "trip_number": trip_number
                }
            else:
                return {"success": False, "result": "face_mismatch", "message": "Face mismatch"}

    except Exception as e:
        logger.error(f"[CHECKIN ERROR] {e}", exc_info=True)
        return {"success": False, "result": "error", "message": "Error during check-in"}

# Registered users route
class UserSelfieOut(BaseModel):
    id: int
    phone_number: str
    created_at: str

    class Config:
        from_attributes = True

@app.get("/registered_users", response_model=list[UserSelfieOut])
async def get_registered_users():
    async with async_session() as session:
        result = await session.execute(select(UserSelfie).order_by(UserSelfie.created_at.desc()))
        users = result.scalars().all()
        return [
            UserSelfieOut(
                id=user.id,
                phone_number=user.phone_number,
                created_at=user.created_at.isoformat()
            )
            for user in users
        ]
