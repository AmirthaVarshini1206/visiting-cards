from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import traceback
from dotenv import load_dotenv
from services.ollama_service import OllamaService
from services.gemini_service import GeminiService
from services.sheet_service import SheetService
import json

load_dotenv()


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default

app = FastAPI(title="Visiting Card Extractor API")

# Enable CORS for Flutter communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Services
ollama = OllamaService()
gemini = GeminiService()
sheet_id = os.getenv("GOOGLE_SHEET_ID")

# Smart detect Render credentials path
cred_file = os.getenv("CREDENTIALS_FILE")
if not cred_file:
    if os.path.exists("/etc/secrets/credentials.json"):
        cred_file = "/etc/secrets/credentials.json"
    else:
        cred_file = "credentials.json"

sheets = SheetService(cred_file, sheet_id)
backend_host = os.getenv("BACKEND_HOST", "0.0.0.0")
backend_port = _env_int("PORT", _env_int("BACKEND_PORT", 8000))

@app.get("/")
async def root():
    return {"status": "online", "message": "Visiting Card Extractor Backend is running"}

@app.get("/models")
async def get_models():
    """Return only the cloud model for V2"""
    return {"models": ["gemma4:31b-cloud"]}

@app.post("/extract")
async def extract_card(
    file: UploadFile = File(...),
    model: str = Form("gemma4:31b-cloud")
):
    """
    1. Receive image from mobile app
    2. Extract data via local Ollama model
    3. If Ollama fails, fallback to Gemini API
    4. Return extracted JSON to app
    """
    try:
        contents = await file.read()
        
        print(f"Processing image with model: {model}...")
        data, error = await ollama.extract_card_data(contents, model_name=model)
        
        if error:
            print(f"Ollama Failed: {error}. Falling back to Gemini...")
            data, error = await gemini.extract_card_data(contents)
            
        if error:
            raise HTTPException(status_code=500, detail=f"AI Extraction Error (All models failed): {error}")
        
        print(f"DEBUG: Extracted data: {data}")
        print(f"DEBUG: point_person: {data.get('point_person')}")
        print(f"DEBUG: organization_name: {data.get('organization_name')}")
            
        return {
            "success": True,
            "data": data
        }
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/sync")
async def sync_to_sheet(data: dict):
    """
    Appends finalized/edited data to Google Sheet
    """
    try:
        is_dup, dup_row = sheets.check_duplicate(data)
        if is_dup:
            return {
                "success": False, 
                "reason": "duplicate", 
                "message": f"Duplicate found at row {dup_row}"
            }
            
        sl_no = sheets.append_card(data)
        return {"success": True, "sl_no": sl_no}
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/data")
async def get_sheet_data():
    """
    Fetches all uploaded cards from the Google Sheet
    """
    try:
        data = sheets.get_all_data()
        return {"success": True, "data": data}
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/insights")
async def get_insights():
    """
    Computes analytics/insights from the Google Sheet data.
    Returns aggregated statistics for the Insights dashboard.
    """
    try:
        insights = sheets.get_insights()
        return {"success": True, "insights": insights}
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host=backend_host, port=backend_port)
