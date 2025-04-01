from flask import Blueprint
from app.controllers.scan_barcodes import scan_barcodes
from app.controllers.extract_data import extract_data

api_bp = Blueprint('api', __name__)

# label scanning / parsing
api_bp.route("/scan-barcodes", methods=["POST", "OPTIONS"])(scan_barcodes)
api_bp.route("/extract-data", methods=["POST", "OPTIONS"])(extract_data)



