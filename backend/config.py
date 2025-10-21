import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# API configuration
OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "gemma3:1b"

# CORS configuration
CORS_ORIGINS = [""]

# Email configuration
EMAIL_ENABLED = os.getenv('EMAIL_ENABLED', 'false').lower() == 'true'
EMAIL_HOST = os.getenv('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.getenv('EMAIL_PORT', '587'))
EMAIL_USER = os.getenv('EMAIL_USER', '')  # Your Gmail address
EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD', '')  # App password
EMAIL_FROM = os.getenv('EMAIL_FROM', 'noreply@intern-analytics.com')
EMAIL_FROM_NAME = os.getenv('EMAIL_FROM_NAME', 'Intern Analytics System')