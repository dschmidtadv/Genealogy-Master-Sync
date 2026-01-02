import sqlite3
import time
import os
# import requests  # TODO: Add when API calls are implemented
import uuid

# Configuration
RM_DB_PATH = "/data/rm_data/MasterTree.rmtree"
GRAMPS_API_URL = "http://grampsweb:5000/api"
CHECK_INTERVAL = 300  # Check every 5 minutes

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

        # Extract Persons with Ancestry Links
        # Query based on research into LinkAncestryTable
        cursor.execute("""
            SELECT p.PersonID, n.Given, n.Surname, l.extID 
            FROM PersonTable p
            JOIN NameTable n ON p.PersonID = n.OwnerID
            LEFT JOIN LinkAncestryTable l ON p.PersonID = l.rmID
            WHERE n.IsPrimary = 1
        """)
        
        persons = cursor.fetchall()
        print(f"Found {len(persons)} persons in RootsMagic.")

        # Sync logic would go here:
        # 1. Iterate through persons
        # 2. Check if they exist in Gramps (via API)
        # 3. Create or Update
        
        conn.close()
        print("Sync complete.")

    except Exception as e:
        print(f"Sync failed: {e}")

if __name__ == "__main__":
    print("Starting Genealogy Sync Worker...")
    check_db_changes()
