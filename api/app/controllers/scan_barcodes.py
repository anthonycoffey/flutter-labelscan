from flask import Flask, jsonify, request
from pyzbar.pyzbar import decode
from PIL import Image
import io

app = Flask(__name__)

def scan_barcodes():
  
  if request.method == "OPTIONS":
    return "", 204
  
  # get file attachment 'file'
  if 'file' not in request.files:
    return jsonify({"error": "No file part"}), 400
  
  file = request.files['file']
  if file.filename == '':
    return jsonify({"error": "No selected file"}), 400
  
  # analyze image and extract data from bar codes
  image = Image.open(io.BytesIO(file.read()))
  barcodes = decode(image)
  
  # create json object of extracted data and return as response
  barcode_data = []
  for barcode in barcodes:
    barcode_info = {
      'type': barcode.type,
      'data': barcode.data.decode('utf-8')
    }
    barcode_data.append(barcode_info)
  
  return jsonify({"barcode_data": barcode_data}), 200