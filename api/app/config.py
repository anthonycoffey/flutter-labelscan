import os
from dotenv import load_dotenv

class Config:
    env_file = '.env.development' if os.getenv('FLASK_ENV') == 'development' else '.env'
    load_dotenv(os.path.join(os.path.dirname(__file__), '..', env_file))
    FLASK_ENV = os.getenv("FLASK_ENV", "production")
    DEBUG = os.getenv("FLASK_DEBUG", "")
    TESTING = os.getenv("FLASK_TESTING", "")
    GCLOUD_PROJECT = os.getenv("GCLOUD_PROJECT", "")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
    
    