import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

if not GEMINI_API_KEY:
    print("❌ No API key found in .env file")
else:
    print(f"✅ API Key found: {GEMINI_API_KEY[:10]}...")
    
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        print("\n📋 Available models:\n")
        
        for model in genai.list_models():
            if 'generateContent' in model.supported_generation_methods:
                print(f"✅ {model.name}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
