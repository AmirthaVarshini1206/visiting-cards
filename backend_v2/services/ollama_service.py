import requests
import base64
import json
import os

class OllamaService:
    def __init__(self, base_url=None):
        self.base_url = base_url or os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
        self.api_key = os.getenv("OLLAMA_API_KEY", "")

    def _generate(self, payload):
        headers = {}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
            
        response = requests.post(
            f"{self.base_url}/api/generate",
            json=payload,
            headers=headers,
            timeout=300
        )
        response.raise_for_status()
        return response.json()

    async def extract_card_data(self, image_bytes, model_name="gemma4:31b-cloud"):
        """
        Extract structured data from a visiting card image using a local or cloud Ollama model.
        """
        # Encode image to base64
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')

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

        payload = {
            "model": model_name,
            "prompt": prompt,
            "stream": False,
            "images": [image_b64],
            "format": "json"
        }

        try:
            result = self._generate(payload)
            
            # Extract and clean the response text
            extracted_text = result.get("response", "").strip()
            if extracted_text.startswith("```json"):
                extracted_text = extracted_text[7:]
            if extracted_text.startswith("```"):
                extracted_text = extracted_text[3:]
            if extracted_text.endswith("```"):
                extracted_text = extracted_text[:-3]
            extracted_text = extracted_text.strip()
            
            # Parse and validate the response
            data = json.loads(extracted_text)
            print(f\"DEBUG Ollama: Parsed JSON: {data}\")
            
            # Validate critical fields
            if not data.get("point_person") or data.get("point_person", "").lower() in ["unknown", "not found", ""]:
                return None, "Could not extract person name from card. Please use a clearer image."
            if not data.get("organization_name") or data.get("organization_name", "").lower() in ["unknown", "not found", ""]:
                return None, "Could not extract organization name from card. Please use a clearer image."
                
            return data, None
        except requests.HTTPError as e:
            error_text = ""
            try:
                error_text = e.response.json().get("error", "")
            except Exception:
                error_text = str(e)


            return None, error_text or str(e)
        except Exception as e:
            return None, str(e)

