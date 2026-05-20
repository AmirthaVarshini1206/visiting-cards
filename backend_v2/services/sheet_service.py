import gspread
from oauth2client.service_account import ServiceAccountCredentials
from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()

class SheetService:
    def __init__(self, credentials_file, sheet_id):
        self.credentials_file = credentials_file
        self.sheet_id = sheet_id
        self.scope = [
            "https://spreadsheets.google.com/feeds",
            "https://www.googleapis.com/auth/drive"
        ]
        self.sheet = None

    def _connect(self):
        if not self.sheet:
            try:
                if os.path.isabs(self.credentials_file):
                    cred_path = Path(self.credentials_file)
                else:
                    base_dir = Path(__file__).resolve().parent.parent.parent
                    cred_path = base_dir / self.credentials_file

                # Ultimate Fallback for Render Secret Files
                if not cred_path.exists() and os.path.exists("/etc/secrets/credentials.json"):
                    cred_path = Path("/etc/secrets/credentials.json")
                
                creds = ServiceAccountCredentials.from_json_keyfile_name(str(cred_path), self.scope)
                client = gspread.authorize(creds)
                self.sheet = client.open_by_key(self.sheet_id).sheet1
            except Exception as e:
                raise Exception(f"Failed to connect to Google Sheets: {str(e)}")

    def get_next_sl_no(self):
        self._connect()
        try:
            all_values = self.sheet.get_all_values()
            if len(all_values) <= 1:
                return 1
            last_sl = all_values[-1][0]
            try:
                return int(last_sl) + 1
            except:
                return len(all_values)
        except:
            return 1

    def check_duplicate(self, data):
        """Check if entry already exists based on name, number, or email."""
        self._connect()
        person_name = data.get("point_person", "")
        contact_number = data.get("contact_number", "")
        contact_email = data.get("contact_email", "")

        if not person_name and not contact_number and not contact_email:
            return False, None

        try:
            all_values = self.sheet.get_all_values()
            for row_idx, row in enumerate(all_values[1:], start=2):
                if len(row) < 8:
                    continue
                
                existing_person = row[4].strip().lower() if len(row) > 4 else ""
                existing_number = row[6].strip().lower() if len(row) > 6 else ""
                existing_email = row[7].strip().lower() if len(row) > 7 else ""

                if person_name and existing_person:
                    if person_name.strip().lower() == existing_person:
                        return True, row_idx

                if contact_number and existing_number:
                    clean_new = "".join(filter(str.isdigit, str(contact_number)))
                    clean_existing = "".join(filter(str.isdigit, str(existing_number)))
                    if clean_new and clean_existing and clean_new == clean_existing:
                        return True, row_idx

                if contact_email and existing_email:
                    if str(contact_email).strip().lower() == existing_email:
                        return True, row_idx
                        
            return False, None
        except Exception as e:
            raise Exception(f"Failed to check duplicate: {str(e)}")

    def append_card(self, data):
        """
        Appends extracted card data to the Google Sheet.
        Expects data keys matching the Gemini output.
        """
        self._connect()
        sl_no = self.get_next_sl_no()
        
        row = [
            sl_no,
            data.get("organization_type", "").upper(),
            data.get("organization_name", ""),
            data.get("location", ""),
            data.get("point_person", ""),
            data.get("department", ""),
            data.get("contact_number", ""),
            data.get("contact_email", ""),
            "", # Address
            "", # URL
            "API-Upload" # Remark
        ]
        
        try:
            self.sheet.append_row(row)
            return sl_no
        except Exception as e:
            raise Exception(f"Failed to append row: {str(e)}")

    def get_all_data(self):
        """
        Fetches all records from the Google Sheet.
        Returns a list of dictionaries where keys are column headers.
        """
        self._connect()
        try:
            records = self.sheet.get_all_records()
            # Sort by SL No descending so newest is first
            # The records might have 'SL No' as key or whatever is in the first column.
            # We'll just reverse the list so the latest uploads show up first.
            records.reverse()
            return records
        except Exception as e:
            raise Exception(f"Failed to fetch data: {str(e)}")
