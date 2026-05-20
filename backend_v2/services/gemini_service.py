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
        Read the visiting card image and extract the following information into a structured JSON format.
        
        REQUIRED FIELDS:
        1. organization_name: Full name of the company, university, or institution.
        2. point_person: Full name of the person on the card.
        3. department: Designation, job title, or department.
        4. location: City, State, or Country only (not full address).
        5. contact_number: Phone or mobile number.
        6. contact_email: Email address.
        7. organization_type: One of [university, business, consultancy, NGO, startup, government].
        
        Respond STRICTLY with a valid JSON object. Do not include any preamble or extra text.
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
            
            return json.loads(extracted_text), None
        except Exception as e:
            return None, f"Gemini API Error: {str(e)}"
