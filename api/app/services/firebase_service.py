import firebase_admin
from firebase_admin import credentials, auth
import os
from google.cloud import storage
from flask import current_app

def initialize_firebase(app):
  if app.config.get('FLASK_ENV') == "development":
    print("Initializing Firebase in development mode")
    cred = credentials.Certificate("api/firebase-credentials.json")
    os.environ["FIREBASE_AUTH_EMULATOR_HOST"] = "localhost:9099"
    os.environ["FIRESTORE_EMULATOR_HOST"] = "localhost:9090"
    # os.environ["STORAGE_EMULATOR_HOST"] = "localhost:9199" # commented out for cloud vision, as it cannot access emulator storage
    firebase_admin.initialize_app(cred)
  else:
    print("Initializing Firebase in production mode")
    firebase_admin.initialize_app(credentials.ApplicationDefault())

def upload_file_to_firebase(file_stream, content_type, unique_filename, bucket_name):
    try:
        storage_client = storage.Client(project="flutter-labelscan")
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(unique_filename)
        blob.upload_from_file(file_stream, content_type=content_type)
        return unique_filename
    except Exception as e:
        current_app.logger.error(f"File upload error: {str(e)}")
        raise

def delete_file_from_firebase(bucket_name, filename):
    """Deletes a file from the specified Firebase Storage bucket."""
    try:
        storage_client = storage.Client(project="flutter-labelscan")
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(filename)
        blob.delete()
        current_app.logger.info(f"Successfully deleted {filename} from bucket {bucket_name}")
    except Exception as e:
        current_app.logger.error(f"Error deleting file {filename} from bucket {bucket_name}: {str(e)}")
        # Decide if you want to raise the exception or just log it
        # raise

def authenticate_user(token):
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        current_app.logger.error(f"Authentication error: {str(e)}")
        return None
