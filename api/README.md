# API Documentation

## Project Overview

This project is a Flask-based REST API designed to handle file uploads and parsing using Google Cloud Vision and Firebase services. It is structured to follow enterprise-level best practices, ensuring maintainability and scalability.

## Directory Structure

The project is organized as follows:


note: 
- `firebase-credentials.json` should be stored in parent root dir in `/api` folder

## Setup Instructions

1. **Create a Virtual Environment**
   ```bash
  cd api
   python -m venv venv
   source venv/bin/activate  # On Windows use `venv\Scripts\activate`
   ```

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Set Up Firebase Credentials**
   - Place your Firebase credentials JSON file in the `data` directory and ensure it is named `firebase-credentials.json`.

4. **Run the Application**
   ```bash
   python -m app
   ```