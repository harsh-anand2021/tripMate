import os
import random
import logging
import asyncio
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    MessageHandler,
    ContextTypes,
    filters
)
import httpx

from db import create_table, store_otp, verify_otp

# Load environment variables
load_dotenv()
create_table()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# User state tracking
user_states = {}

# Command: /start
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Welcome! Send your 10-digit phone number to get an OTP.")

# Validate phone number
def is_valid_phone(text):
    return text.isdigit() and len(text) == 10

# Handle phone or OTP input
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text
    chat_id = update.effective_chat.id
    logger.info(f"Chat ID: {chat_id} | Message: {text}")

    if chat_id not in user_states:
        if is_valid_phone(text):
            otp = f"{random.randint(100000, 999999)}"
            store_otp(text, otp)
            user_states[chat_id] = {"phone": text}
            await update.message.reply_text(f"Your OTP is: {otp}\nNow enter the OTP to verify.")
        else:
            await update.message.reply_text("❗ Please send a valid 10-digit phone number.")
    else:
        phone = user_states[chat_id]["phone"]
        if verify_otp(phone, text):
            await update.message.reply_text("✅ OTP verified! Navigating to the next page...")
            del user_states[chat_id]
        else:
            await update.message.reply_text("❌ Incorrect OTP. Try again.")

# Register the webhook with Telegram
async def set_webhook(token: str, url: str):
    set_webhook_url = f"https://api.telegram.org/bot{token}/setWebhook"
    async with httpx.AsyncClient() as client:
        response = await client.post(set_webhook_url, params={"url": url})
        if response.status_code == 200 and response.json().get("ok"):
            logger.info("✅ Webhook set successfully.")
        else:
            logger.error("❌ Failed to set webhook: %s", response.text)

# Main async function
async def main():
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    webhook_url = os.getenv("WEBHOOK_URL")

    if not token or not webhook_url:
        raise ValueError("TELEGRAM_BOT_TOKEN or WEBHOOK_URL not found in .env")

    app = ApplicationBuilder().token(token).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    # Set webhook with Telegram
    await set_webhook(token, webhook_url)

    logger.info("🚀 Telegram bot is running with webhook...")
    await app.run_webhook(
        listen="0.0.0.0",
        port=8000,
        url_path="webhook",
        webhook_url=webhook_url,
    )

# Entry point
if __name__ == "__main__":
    asyncio.run(main())
