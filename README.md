# Mining-Crime-Analysis

## How to run everything E2E (API + Flutter):

### Backend (FastAPI)
- From root: cd back
- Create venv and activate (bash): python3 -m venv .venv && source .venv/bin/activate
- Install deps: python3 -m pip install -r requirements.txt
- Ensure the dataset file exists at back/../../datasets/crime_data_2020_to_present.csv (relative to back/main.py). If it’s elsewhere, update the pd.read_csv(...) path in back/main.py to the correct location.
- Run the server: uvicorn main:app --reload
- Check docs: open http://127.0.0.1:8000/docs

### Frontend (Flutter)
- Install Flutter SDK and set up a device/emulator (or Chrome for web).
- From repo root: cd frontend
- Get packages: flutter pub get
- Run the app on emulator: flutter run

### If the frontend needs to call the backend, ensure its config points to your backend URL (e.g., http://127.0.0.1:8000); update any hardcoded API base URL if present

## Key Files in Project Structure
- main.py: FastAPI app that loads crime data, exposes endpoints for seasonal patterns, Apriori rules, and chi-square stats
- requirements.txt: Python dependencies for the backend