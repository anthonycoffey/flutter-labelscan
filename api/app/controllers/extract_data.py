from flask import request, jsonify
from google import genai
from datetime import datetime
from app.services.firebase_service import upload_file_to_firebase
from google.cloud import vision
from google.genai import types
from flask import current_app
from google.protobuf import json_format
import json
import asyncio

def extract_data():
  
  if request.method == "OPTIONS":
    return "", 204

  if "file" not in request.files:
    return jsonify({"status": "error", "message": "No file part in the request"}), 400

  file = request.files.get("file")

  if file.filename == "":
    return jsonify({"status": "error", "message": "No selected file"}), 400

  if file.content_type not in ["image/jpeg", "image/png", "image/jpg", "image/webp", "image/heic", "image/heif"]:
    return jsonify({"status": "error", "message": "Invalid file type."}), 400

  timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
  unique_filename = f"{timestamp}_{file.filename}"
  bucket_name = 'flutter-labelscan.firebasestorage.app'
  unique_filename = upload_file_to_firebase(file.stream, file.content_type, unique_filename, bucket_name)

  client = vision.ImageAnnotatorClient()
  image = vision.Image(source=vision.ImageSource(gcs_image_uri=f"gs://{bucket_name}/{unique_filename}"))

  cloud_vision_response = client.annotate_image({
  'image': image,
  'features': [
    vision.Feature(type=vision.Feature.Type.TEXT_DETECTION),
    vision.Feature(type=vision.Feature.Type.SAFE_SEARCH_DETECTION),
  ],
  })

  # Convert the Cloud Vision response to JSON string
  cloud_vision_response_json = json_format.MessageToJson(cloud_vision_response._pb)

  try:
    # Create a new event loop for this thread if one doesn't exist
    try:
      loop = asyncio.get_event_loop()
    except RuntimeError:
      # Create and set a new event loop if one doesn't exist in this thread
      loop = asyncio.new_event_loop()
      asyncio.set_event_loop(loop)
    
    client = genai.Client(
      api_key=current_app.config.get('GEMINI_API_KEY'),
    )

    model = "gemini-2.0-flash"
    contents = [
      types.Content(
      role="user",
      parts=[
        types.Part.from_text(
        text=""" 1. take this cloud vision api response and extract price data from it
                 2. return JSON object with price data in the following schema:
                 {"description":"[infer product desctription here]","amount":"[extracted price here]"}
        """,
        ),
        types.Part.from_text(
        text=cloud_vision_response_json
        ),
      ],
      ),
    ]
    generate_content_config = types.GenerateContentConfig(
      temperature=1,
      top_p=0.95,
      top_k=40,
      max_output_tokens=8192,
      response_mime_type="application/json",
    )

    response_text = ""
    for chunk in client.models.generate_content_stream(
      model=model,
      contents=contents,
      config=generate_content_config,
    ):
      response_text += chunk.text

    try:
      extracted_data = json.loads(response_text)
    except json.JSONDecodeError as e:
      print(e)
      return jsonify({"status": "error", "message": "Failed to parse JSON response"}), 500

   
  except Exception as e:
    print(e)
    return jsonify({"status": "error", "message": str(e)}), 500
  

  return jsonify({'data': extracted_data})