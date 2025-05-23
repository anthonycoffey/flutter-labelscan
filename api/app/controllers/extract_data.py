from flask import request, jsonify
from google import genai
from datetime import datetime
from app.services.firebase_service import upload_file_to_firebase, delete_file_from_firebase
from google.cloud import vision
from google.genai import types
from flask import current_app
from google.protobuf import json_format
import json
import asyncio

def extract_data():
  unique_filename = None  # Initialize unique_filename
  bucket_name = 'flutter-labelscan.firebasestorage.app' # Define bucket_name early

  if request.method == "OPTIONS":
    return "", 204

  if "file" not in request.files:
    return jsonify({"status": "error", "message": "No file part in the request"}), 400

  file = request.files.get("file")

  if file.filename == "":
    return jsonify({"status": "error", "message": "No selected file"}), 400

  # More robust check: ensure it's an image type
  if not file.content_type or not file.content_type.startswith('image/'):
    return jsonify({"status": "error", "message": f"Invalid file type: {file.content_type}. Expected an image."}), 400

  timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
  original_filename = file.filename # Keep original filename for deletion if needed
  unique_filename = f"{timestamp}_{original_filename}"
  # Note: upload_file_to_firebase might modify unique_filename if there's a collision,
  # but we'll use the returned name for deletion.
  unique_filename = upload_file_to_firebase(file.stream, file.content_type, unique_filename, bucket_name)

  client = vision.ImageAnnotatorClient()
  image = vision.Image(source=vision.ImageSource(gcs_image_uri=f"gs://{bucket_name}/{unique_filename}"))

  cloud_vision_response = client.annotate_image({
    'image': image,
    'features': [
      vision.Feature(type=vision.Feature.Type.TEXT_DETECTION),
      vision.Feature(type=vision.Feature.Type.SAFE_SEARCH_DETECTION),
      vision.Feature(type=vision.Feature.Type.LABEL_DETECTION),
      vision.Feature(type=vision.Feature.Type.IMAGE_PROPERTIES),
      vision.Feature(type=vision.Feature.Type.OBJECT_LOCALIZATION),
      vision.Feature(type=vision.Feature.Type.LOGO_DETECTION),
      vision.Feature(type=vision.Feature.Type.LANDMARK_DETECTION),
      vision.Feature(type=vision.Feature.Type.FACE_DETECTION),
      vision.Feature(type=vision.Feature.Type.DOCUMENT_TEXT_DETECTION),
      vision.Feature(type=vision.Feature.Type.CROP_HINTS),
      vision.Feature(type=vision.Feature.Type.WEB_DETECTION),
      vision.Feature(type=vision.Feature.Type.PRODUCT_SEARCH),
    ],
  })

  # Check Safe Search results immediately after Vision API call
  safe_search = cloud_vision_response.safe_search_annotation
  # Define likelihood levels that trigger the block (adjust as needed)
  trigger_likelihoods = (
      vision.Likelihood.LIKELY,
      vision.Likelihood.VERY_LIKELY,
  )

  unsafe_content_detected = (
      safe_search.adult in trigger_likelihoods or
      safe_search.violence in trigger_likelihoods or
      safe_search.racy in trigger_likelihoods # Consider adding medical or spoof if necessary
  )

  if unsafe_content_detected:
      current_app.logger.warning(f"Unsafe content detected in {unique_filename}. Deleting file.")
      try:
          delete_file_from_firebase(bucket_name, unique_filename)
          current_app.logger.info(f"Deleted unsafe file: {unique_filename}")
      except Exception as delete_error:
          # Log deletion error but still return the error response
          current_app.logger.error(f"Failed to delete unsafe file {unique_filename}: {str(delete_error)}")
      
      # Store filename for message, then set to None so finally block skips deletion
      filename_for_error = unique_filename 
      unique_filename = None 

      return jsonify({
          "status": "error",
          "message": f"Image rejected due to potentially unsafe content ({filename_for_error})."
      }), 422 # 422 Unprocessable Entity seems appropriate

  # Convert the Cloud Vision response to JSON string only if safe
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
        text=""" 1. take this cloud vision api response and try to infer the product description and price data from the response
                 2. convert dollar price to cents
                 3. return JSON object with price data in the following schema:
                 {"description":"*infer product description here*","amount":"*extracted price here (cents)*"}
                 ** note: description should be a single line of text, no new lines and a maximum of 35 characters
                 ** do not wrap the response in an array, just return the JSON object
                 ** never include price in the description
        """,
        ),
        types.Part.from_text(
        text=cloud_vision_response_json
        ),
      ],
      ),
    ]
    generate_content_config = types.GenerateContentConfig(
      temperature=0.75,
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
      print(extracted_data)
    except json.JSONDecodeError as e:
      print(e)
      return jsonify({"status": "error", "message": "Failed to parse JSON response"}), 500

   
  except Exception as e:
    print(e)
    return jsonify({"status": "error", "message": str(e)}), 500
  finally:
    # Ensure the file is deleted from Firebase Storage *if it wasn't already deleted* by the safe search check
    if unique_filename: # This check prevents attempting to delete a None filename
      try:
        delete_file_from_firebase(bucket_name, unique_filename)
        current_app.logger.info(f"Cleaned up processed file: {unique_filename}")
      except Exception as delete_error:
        # Log deletion error but don't fail the request
        current_app.logger.error(f"Failed to delete processed file {unique_filename}: {str(delete_error)}")

  return jsonify({'data': extracted_data})
