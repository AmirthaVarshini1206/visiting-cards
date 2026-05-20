import os
import json
import google.generativeai as genai

class GeminiService:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY", "")
        if self.api_key:
            genai.configure(api_key=self.api_key)

    async def extract_card_data(self, image_bytes):
        if not self.api_key:
            return None, "GEMINI_API_KEY is not set"

        prompt = """
        You are a business card extraction expert. Carefully read the visiting card image and extract the following information into a structured JSON format.
        
        CRITICAL - Extract EXACTLY these fields:
        1. organization_name: Full name of the company/organization (MUST extract - do not leave empty)
        2. point_person: Full name of the person on the card (MUST extract the actual name - do not leave empty or use "Unknown")
        3. department: Job title, designation, or department
        4. location: City, State, or Country (extraction area only)
        5. contact_number: Phone or mobile number
        6. contact_email: Email address
        7. organization_type: One of [university, business, consultancy, NGO, startup, government]
        
        IMPORTANT:
        - If you cannot read a field clearly, use "Not Found" instead of leaving it empty or using "Unknown"
        - For point_person: Extract the person's actual name from the card. If illegible, write "Not Found"
        - Respond ONLY with valid JSON, no preamble or markdown
        """

        try:
            model = genai.GenerativeModel('gemini-1.5-flash')
            
            # Gemini expects data with mime type
            image_part = {
                "mime_type": "image/jpeg",
                "data": image_bytes
            }
            
            response = model.generate_content([prompt, image_part])
            
            extracted_text = response.text.strip()
            if extracted_text.startswith("```json"):
                extracted_text = extracted_text[7:]
            if extracted_text.startswith("```"):
                extracted_text = extracted_text[3:]
            if extracted_text.endswith("```"):
                extracted_text = extracted_text[:-3]
            extracted_text = extracted_text.strip()
            
            data = json.loads(extracted_text)
            
            # Validate critical fields
            if not data.get("point_person") or data.get("point_person", "").lower() in ["unknown", "not found", ""]:
                return None, "Could not extract person name from card. Please check image quality."
            if not data.get("organization_name") or data.get("organization_name", "").lower() in ["unknown", "not found", ""]:
                return None, "Could not extract organization name from card. Please check image quality."
                
            return data, None
        except Exception as e:
            return None, f"Gemini API Error: {str(e)}"
