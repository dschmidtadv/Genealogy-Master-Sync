import sqlite3
import time
import os
import requests
import uuid

# Configuration
RM_DB_PATH = "/Users/dietrichschmidt/Documents/FS.rmtree"
GRAMPS_API_URL = "http://localhost:5001/api"  # Use localhost for host testing
CHECK_INTERVAL = 300  # Check every 5 minutes
GRAMPS_USER = "admin"  # Default Gramps user
GRAMPS_PASS = "admin"  # Default Gramps password

def rmnocase_collation(s1, s2):
    """
    Simulates the RMNOCASE collation used by RootsMagic.
    Essential for querying NameTable without crashing.
    """
    s1 = s1.lower() if s1 else ""
    s2 = s2.lower() if s2 else ""
    if s1 == s2: return 0
    if s1 < s2: return -1
    return 1

def parse_rm_date(rm_date):
    """Parse RootsMagic date format to Gramps date dict."""
    if not rm_date or rm_date == "None":
        return None
    # RootsMagic date formats: D.+YYYYMMDD..+... or D.+YYYY0000..+... etc.
    import re
    match = re.search(r'D\.\+(\d{4})(\d{2})(\d{2})\.\.', rm_date)
    if match:
        year, month, day = map(int, match.groups())
        dateval = [0, 0, year, False]  # Default to year only
        if month != 0:
            dateval[1] = month
        if day != 0:
            dateval[0] = day
        return {
            "_class": "Date",
            "calendar": 0,  # Gregorian
            "dateval": dateval,
            "format": None,
            "modifier": 0,
            "newyear": 0,
            "quality": 0,
            "sortval": 0,
            "text": ""
        }
    return None

def get_gramps_token():
    """Authenticate with Gramps Web and return access token."""
    try:
        response = requests.post(f"{GRAMPS_API_URL}/token", json={
            "username": GRAMPS_USER,
            "password": GRAMPS_PASS
        })
        response.raise_for_status()
        return response.json()["access_token"]
    except Exception as e:
        print(f"Failed to authenticate with Gramps: {e}")
        return None

def check_db_changes():
    """
    Watches the file modification time of the RootsMagic DB.
    """
    last_mtime = 0
    while True:
        try:
            if os.path.exists(RM_DB_PATH):
                current_mtime = os.path.getmtime(RM_DB_PATH)
                if current_mtime > last_mtime:
                    print(f"Change detected in {RM_DB_PATH}. Starting sync...")
                    sync_data()
                    last_mtime = current_mtime
            else:
                print("Waiting for RootsMagic database creation...")
        except Exception as e:
            print(f"Error watching file: {e}")

        time.sleep(CHECK_INTERVAL)

def sync_data():
    """
    Extracts data from RootsMagic and pushes to Gramps.
    """
    try:
        # Connect to RootsMagic SQLite
        conn = sqlite3.connect(RM_DB_PATH)
        conn.create_collation("RMNOCASE", rmnocase_collation)
        cursor = conn.cursor()

        # Extract Persons
        # Check if LinkAncestryTable exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='LinkAncestryTable'")
        has_link_table = cursor.fetchone() is not None

        if has_link_table:
            cursor.execute("""
                SELECT p.PersonID, n.Given, n.Surname, l.extID, e.Date as birth_date
                FROM PersonTable p
                JOIN NameTable n ON p.PersonID = n.OwnerID
                LEFT JOIN LinkAncestryTable l ON p.PersonID = l.rmID
                LEFT JOIN EventTable e ON p.PersonID = e.OwnerID AND e.EventType = 1
                WHERE n.IsPrimary = 1
            """)
        else:
            cursor.execute("""
                SELECT p.PersonID, n.Given, n.Surname, NULL as extID, e.Date as birth_date
                FROM PersonTable p
                JOIN NameTable n ON p.PersonID = n.OwnerID
                LEFT JOIN EventTable e ON p.PersonID = e.OwnerID AND e.EventType = 1
                WHERE n.IsPrimary = 1
            """)
        
        persons = cursor.fetchall()
        print(f"Found {len(persons)} persons in RootsMagic.")

        # Print first 10 persons for verification
        for person in persons[:10]:
            person_id, given, surname, ext_id, birth_date = person
            print(f"Person: {given} {surname}, Birth: {birth_date}")

        # Sync to Gramps
        token = get_gramps_token()
        if not token:
            print("Skipping sync due to authentication failure.")
            conn.close()
            return

        headers = {"Authorization": f"Bearer {token}"}

        synced_count = 0
        for person in persons:
            person_id, given, surname, ext_id, birth_date = person
            # Create person in Gramps
            event_handle = None
            parsed_date = parse_rm_date(birth_date)
            if parsed_date:
                event_data = {
                    "_class": "Event",
                    "type": "Birth",
                    "date": parsed_date
                }
                try:
                    event_response = requests.post(f"{GRAMPS_API_URL}/events", json=event_data, headers=headers)
                    if event_response.status_code == 201:
                        event_result = event_response.json()[0]
                        event_handle = event_result["handle"]
                        print(f"Created birth event for {given} {surname}")
                    else:
                        print(f"Failed to create birth event for {given} {surname}: {event_response.text}")
                except Exception as e:
                    print(f"Error creating birth event for {given} {surname}: {e}")

            person_data = {
                "_class": "Person",
                "primary_name": {
                    "first_name": given,
                    "surname": surname,
                    "surname_list": [{"surname": surname}] if surname else []
                }
            }
            if event_handle:
                person_data["event_ref_list"] = [{
                    "_class": "EventRef",
                    "ref": event_handle,
                    "role": {"_class": "EventRoleType", "string": "", "value": 1}
                }]
                person_data["birth_ref_index"] = 0

            try:
                response = requests.post(f"{GRAMPS_API_URL}/people", json=person_data, headers=headers)
                if response.status_code == 201:
                    created_person = response.json()[0]
                    print(f"Created person response: {created_person}")
                    gramps_person_id = created_person.get("handle") or created_person.get("id")
                    if not gramps_person_id:
                        print(f"No ID in response for {given} {surname}")
                        continue
                    print(f"Created person: {given} {surname}")
                    synced_count += 1
                    # Link the birth event
                    if event_handle:
                        # Get current person data
                        person_get_response = requests.get(f"{GRAMPS_API_URL}/people/{gramps_person_id}", headers=headers)
                        if person_get_response.status_code == 200:
                            current_person = person_get_response.json()
                            current_person["event_ref_list"] = [{
                                "_class": "EventRef",
                                "ref": event_handle,
                                "role": {"_class": "EventRoleType", "string": "", "value": 1}
                            }]
                            current_person["birth_ref_index"] = 0
                            # Update person
                            update_response = requests.put(f"{GRAMPS_API_URL}/people/{gramps_person_id}", json=current_person, headers=headers)
                            if update_response.status_code == 200:
                                print(f"Linked birth event for {given} {surname}")
                            else:
                                print(f"Failed to link birth event for {given} {surname}: {update_response.text}")
                        else:
                            print(f"Failed to get person for linking {given} {surname}")
                else:
                    print(f"Failed to create {given} {surname}: {response.text}")
            except Exception as e:
                print(f"Error creating {given} {surname}: {e}")

        print(f"Synced {synced_count} persons to Gramps.")

        conn.close()
        print("Sync complete.")

    except Exception as e:
        print(f"Sync failed: {e}")

def test_sync_verification():
    """Test that persons in Gramps have names and birth dates."""
    token = get_gramps_token()
    if not token:
        print("Cannot authenticate for test.")
        return

    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{GRAMPS_API_URL}/people", headers=headers)
    if response.status_code != 200:
        print(f"Failed to get people: {response.text}")
        return

    people = response.json()
    print(f"Found {len(people)} people in Gramps.")

    verified = 0
    for person in people[:10]:  # Test first 10
        handle = person.get("handle")
        # Get full person details
        detail_response = requests.get(f"{GRAMPS_API_URL}/people/{handle}", headers=headers)
        if detail_response.status_code == 200:
            details = detail_response.json()
            print(f"Details: {details}")
            name = details.get("primary_name", {})
            first = name.get("first_name", "")
            surname = name.get("surname", "")
            birth_date = None
            if details.get("birth_ref_index", -1) >= 0:
                event_ref = details.get("event_ref_list", [])[details["birth_ref_index"]]
                event_handle = event_ref.get("ref")
                if event_handle:
                    event_response = requests.get(f"{GRAMPS_API_URL}/events/{event_handle}", headers=headers)
                    if event_response.status_code == 200:
                        event = event_response.json()
                        birth_date = event.get("date", {}).get("dateval")
            
            if first and surname:
                status = f"✓ {first} {surname}"
                if birth_date:
                    status += f" - Birth: {birth_date}"
                else:
                    status += " - No birth date"
                print(status)
                verified += 1
            else:
                print(f"✗ Missing name data for {handle}")

    print(f"Verified {verified} persons with complete name data.")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_sync_verification()
    else:
        print("Starting Genealogy Sync Worker...")
        check_db_changes()
