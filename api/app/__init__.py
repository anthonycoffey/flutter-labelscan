from flask import Flask
from flask_cors import CORS
from app.config import Config
from app.services import initialize_firebase

def create_app():
  app = Flask(__name__)
  
  app.config.from_object(Config)
  
  initialize_firebase(app)

  CORS(app, 
    resources={r"/api/*": {
      "origins": ["*"],
      "supports_credentials": True,
      "allow_headers": ["Content-Type", "Authorization"],
      "methods": ["POST", "OPTIONS", "GET", "PUT", "DELETE"]
    }})

  # Register the blueprint
  from app.routes import api_bp
  app.register_blueprint(api_bp, url_prefix='/api')
  
  return app

if __name__ == "__main__":
  app = create_app()
  app.run(host='0.0.0.0', port=8080)