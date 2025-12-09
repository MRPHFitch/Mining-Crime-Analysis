# Mining-Crime-Analysis

## Data Preprocessing 
The project uses two datasets from Kaggle. To prevent potential filepath issues and keeping clean/efficient code in mind, you can access the datasets without manually downloading the datasets onto your local machine. This is possible with the Kaggle API. If it is preferred to use a manually downloaded dataset, adjust the 'USING_KAGGLEHUB' variable to 'False' and hardcode the filepaths to both datasets. Otherwise, execute the script as is. 
> python3 preprocess_data.py

## Kaggle API setup 
Install the Kaggle library
> pip install kaggle

Obtain your Kaggle API credentials.
A kaggle.json file is generated when you create a new Kaggle API token. This file will hold your username and API key. 
Save this file to:
- Linux/macOS: ~/.kaggle/
- Windows: C:Users\username\ .kaggle\
Run the data preprocessing script
> python3 preprocess_data.py

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
