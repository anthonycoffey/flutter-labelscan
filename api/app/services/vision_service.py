from google.cloud import vision

def annotate_image(image_uri):
    client = vision.ImageAnnotatorClient()
    image = vision.Image(source=vision.ImageSource(gcs_image_uri=image_uri))
    
    response = client.annotate_image({
        'image': image,
        'features': [
            vision.Feature(type=vision.Feature.Type.OBJECT_LOCALIZATION),
            vision.Feature(type=vision.Feature.Type.LABEL_DETECTION),
            vision.Feature(type=vision.Feature.Type.TEXT_DETECTION),
            vision.Feature(type=vision.Feature.Type.SAFE_SEARCH_DETECTION),
            vision.Feature(type=vision.Feature.Type.FACE_DETECTION),
            vision.Feature(type=vision.Feature.Type.LANDMARK_DETECTION),
            vision.Feature(type=vision.Feature.Type.LOGO_DETECTION),
            vision.Feature(type=vision.Feature.Type.IMAGE_PROPERTIES),
            vision.Feature(type=vision.Feature.Type.CROP_HINTS),
            vision.Feature(type=vision.Feature.Type.WEB_DETECTION),
            vision.Feature(type=vision.Feature.Type.DOCUMENT_TEXT_DETECTION),
        ],
    })

    if response.error.message:
        raise Exception(response.error.message)

    labels = response.label_annotations
    text_annotations = response.text_annotations
    object_annotations = response.localized_object_annotations

    extracted_data = {
        "labels": [{"description": label.description, "score": label.score} for label in labels],
        "text": [{"description": text.description, "bounding_poly": text.bounding_poly} for text in text_annotations],
        "objects": [{"name": obj.name, "score": obj.score, "bounding_poly": obj.bounding_poly} for obj in object_annotations]
    }

    return extracted_data