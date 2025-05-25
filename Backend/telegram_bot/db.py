import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

conn = psycopg2.connect(
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASS"),
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
)

def create_table():
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS otp_data (
                phone VARCHAR(10) PRIMARY KEY,
                otp VARCHAR(6)
            );
        """)
        conn.commit()

def store_otp(phone, otp):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO otp_data (phone, otp)
            VALUES (%s, %s)
            ON CONFLICT (phone)
            DO UPDATE SET otp = EXCLUDED.otp;
        """, (phone, otp))
        conn.commit()

def verify_otp(phone, otp):
    with conn.cursor() as cur:
        cur.execute("SELECT otp FROM otp_data WHERE phone = %s", (phone,))
        row = cur.fetchone()
        return row and row[0] == otp
