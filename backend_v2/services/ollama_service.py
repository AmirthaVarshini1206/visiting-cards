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

        payload = {
            "model": model_name,
            "prompt": prompt,
            "stream": False,
            "images": [image_b64],
            "format": "json"
        }

        try:
            result = self._generate(payload)
            
            # The model might return a stringified JSON wrapped in markdown
            extracted_text = result.get("response", "").strip()
            if extracted_text.startswith("```json"):
                extracted_text = extracted_text[7:]
            if extracted_text.startswith("```"):
                extracted_text = extracted_text[3:]
            if extracted_text.endswith("```"):
                extracted_text = extracted_text[:-3]
            extracted_text = extracted_text.strip()
            return json.loads(extracted_text), None
        except requests.HTTPError as e:
            error_text = ""
            try:
                error_text = e.response.json().get("error", "")
            except Exception:
                error_text = str(e)


            return None, error_text or str(e)
        except Exception as e:
            return None, str(e)

