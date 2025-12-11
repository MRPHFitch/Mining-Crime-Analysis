from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
import numpy as np
import traceback
from weather_analysis import get_season, run_seasonal_analysis
from sequence_mining import run_crime_sequence_mining
from scipy.stats import chi2_contingency
from typing import Optional
from kmeans import run_hotspot_kmeans
from mlxtend.frequent_patterns import apriori, association_rules

app = FastAPI()

# Load your dataset
df = pd.read_csv('../crime_data_cleaned.csv')
safetyDF = pd.read_csv('../crime_safety_cleaned.csv')

#Add in the season check for moving forward
def get_season(month):
    if month in [12, 1, 2]:
        return 'Winter'
    elif month in [3, 4, 5]:
        return 'Spring'
    elif month in [6, 7, 8]:
        return 'Summer'
    else:
        return 'Fall'

class HotspotRequest(BaseModel):
    k: int = 5
    max_iter: int = 100
    tol: float = 1e-4
    random_state: Optional[int] = None
    datetime_col: Optional[str] = None
    time_col: Optional[str] = None
    lat_col: Optional[str] = None
    lon_col: Optional[str] = None
    
class AprioriRequest(BaseModel):
    dataset_name: str # 'crime_data' or 'safety_data'

# Renamed df to df_local_param to avoid shadowing global df
def chi_square_for_rule(df_local_param, antecedent, consequent):
    # Both antecedent and consequent are tuples of (column_name, value)
    mask_a = df_local_param[antecedent[0]] == antecedent[1]
    mask_c = df_local_param[consequent[0]] == consequent[1]
    table = pd.crosstab(mask_a, mask_c)
    # More robust check for valid table for chi2
    if table.shape !=(2,2) or (table.values==0).any():
        return None, None
    # Check if there's enough variation for chi2_contingency
    # Ensure there are at least two unique values for both variables in the crosstab
    if len(mask_a.unique()) < 2 or len(mask_c.unique()) < 2:
        return None, None
    chi2, p, _, _ = chi2_contingency(table)
    return chi2, p

# Define parse_onehot function globally
def parse_onehot(item_string: str):
    """
    Parses a one-hot encoded item string (e.g., 'column_name_value')
    to return (original_column_name, value).
    Handles original column names that might contain underscores.
    """
    last_underscore_index = item_string.rfind('_')
    if last_underscore_index != -1:
        col_name = item_string[:last_underscore_index]
        value = item_string[last_underscore_index + 1:]
        return (col_name, value)
    else:
        # Fallback for items that might not be in 'col_value' format
        # This could happen if the column itself was boolean and passed directly
        # or if there's a single item not generated from pd.get_dummies
        return (item_string, True) # Risky, but better than an immediate crash

# Cluster crimes into hotspots using K-Means on latitude, longitude, and cyclical time features
@app.post("/api/hotspots")
def hotspots(request: HotspotRequest):
    df_local = df.copy()
    try:
        result = run_hotspot_kmeans(
            df_local,
            k=request.k,
            max_iter=request.max_iter,
            tol=request.tol,
            random_state=request.random_state,
            datetime_col=request.datetime_col,
            time_col=request.time_col,
            lat_col=request.lat_col,
            lon_col=request.lon_col,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return result

@app.get("/api/seasons")
def seasonal_crime_patterns():
    # It's better to work on a copy of the global df for modifications within an endpoint
    df_local_seasons = df.copy()
    df_local_seasons['date'] = pd.to_datetime(df_local_seasons['date'])
    df_local_seasons['season'] = df_local_seasons['date'].dt.month.apply(get_season)
    # Group by season and crime_type, count occurrences
    season_crime = df_local_seasons.groupby(['season', 'crime_type']).size().reset_index(name='count')
    # Group by season and weapon used, count occurrences
    if 'weapon_used' in df_local_seasons.columns:
        season_weapon = df_local_seasons.groupby(['season', 'weapon_used']).size().reset_index(name='count')
    else:
        season_weapon = []
    return {
        "season_crime": season_crime.to_dict(orient='records'),
        "season_weapon": season_weapon if isinstance(season_weapon, list) else season_weapon.to_dict(orient='records')
    }

@app.post("/api/weather_analysis")
def weather_analysis(request: AprioriRequest):
    selected_df = None
    if request.dataset_name == "crime_data":
        selected_df = df.copy()
    elif request.dataset_name == "safety_data":
        selected_df = safetyDF.copy()
    else:
        raise HTTPException(status_code=400, detail="Invalid dataset_name. Choose 'crime_data' or 'safety_data'.")

    if selected_df is None or selected_df.empty:
        raise HTTPException(status_code=404, detail=f"Dataset '{request.dataset_name}' is empty or not found.")

    try:
        # Call the run_seasonal_analysis function from weather_analysis.py with the selected DataFrame
        return run_seasonal_analysis(selected_df)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Error in seasonal analysis: {exc}")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f'Internal server error during seasonal analysis: {exc}')

    # try:
    #     # Call the refactored function
    #     return run_seasonal_analysis(df)
    # except ValueError as exc:
    #     raise HTTPException(status_code=400, detail=str(exc))
    # except Exception as exc:
    #     raise HTTPException(status_code=500, detail=f'Error during seasonal analysis: {exc}')
    
# Endpoint to preview the cleaned data
@app.get("/api/cleaned_data_preview")
def get_cleaned_data_preview():
    """
    Returns the first 20 rows of the cleaned crime data.
    """
    if safetyDF.empty:
        raise HTTPException(status_code=404, detail="Cleaned data is not available.")
    
    display_columns = [
        'date', 'time', 'crime_type', 'weapon_used', 'city', 'state',
        'victim_age', 'victim_gender', 'victim_race', 'season', 'is_weekend'
    ]
    
    available_columns = [col for col in display_columns if col in safetyDF.columns]
    
    preview_df = (
    safetyDF[available_columns]
    .assign(date=lambda df: pd.to_datetime(df['date'], errors='coerce'))
    .sort_values('date')
    .assign(date=lambda df: df['date'].dt.strftime('%Y-%m-%d'))
    .head(5)
)
    return preview_df.to_dict(orient='records')

#Endpoint for other data preview
@app.get("/api/crime_data_preview")
def get_crime_data_preview():
    """
    Returns the first 5 rows of the main crime data (df).
    """
    if df.empty:
        raise HTTPException(status_code=404, detail="Main crime data is not available.")

    # These columns should exist in crime_data_cleaned.csv as per preprocess_data.py
    display_columns = [
        'date','crime_type', 'latitude', 'longitude', 'weapon_used',
        'is_weekend', 'time_period', 'season'
    ]

    available_columns = [col for col in display_columns if col in df.columns]

    preview_df = (
        df[available_columns]
        .assign(date=lambda df_inner: pd.to_datetime(df_inner['date'], errors='coerce'))
        .sort_values('date')
        .assign(date=lambda df_inner: df_inner['date'].dt.strftime('%Y-%m-%d'))
        .head(5)
    )
    #Replace NaN values in float columns with None
    for col in preview_df.select_dtypes(include=[np.number]).columns:
        if preview_df[col].isnull().any():
            preview_df[col] = preview_df[col].replace({np.nan: None})

    return preview_df.to_dict(orient='records')

@app.get("/api/hotspot_grid")
def get_hotspot_grid():
    """
    Analyzes crime data to generate a hot spot grid based on latitude and longitude bins.
    Returns a JSON object with crime counts grouped by geographic bands.
    """
    df_grid = df.copy() # Use a copy of the global DataFrame

    # Ensure latitude and longitude columns exist and are numeric
    if 'latitude' not in df_grid.columns or 'longitude' not in df_grid.columns:
        raise HTTPException(status_code=400, detail="Latitude or longitude columns not found in data.")
    
    # Drop rows with NaN in 'latitude' or 'longitude'
    df_grid.dropna(subset=['latitude', 'longitude'], inplace=True)
    
    if df_grid.empty:
        raise HTTPException(status_code=400, detail="No valid latitude/longitude data to generate grid.")

    # Define latitude and longitude bins (adjust these values based on your data's geographic spread)
    min_lat, max_lat = df_grid['latitude'].min(), df_grid['latitude'].max()
    min_lon, max_lon = df_grid['longitude'].min(), df_grid['longitude'].max()

    # You might want to adjust bin sizes for different granularities
    lat_bin_size = .05
    lon_bin_size = .05

    lat_bins = np.arange(np.floor(min_lat * 100) / 100, np.ceil(max_lat * 100) / 100 + lat_bin_size, lat_bin_size)
    lon_bins = np.arange(np.floor(min_lon * 100) / 100, np.ceil(max_lon * 100) / 100 + lon_bin_size, lon_bin_size)

    # Bin the data
    df_grid['lat_bin'] = pd.cut(df_grid['latitude'], bins=lat_bins, include_lowest=True, precision=2)
    df_grid['lon_bin'] = pd.cut(df_grid['longitude'], bins=lon_bins, include_lowest=True, precision=2)

    # Count crimes per lat/lon bin
    grid_counts = df_grid.groupby(['lat_bin', 'lon_bin']).size().unstack(fill_value=0)

    # Convert to a list of dictionaries for JSON output
    output_grid = []
    for lat_band, row in grid_counts.iterrows():
        # Format lat_band to a readable string (e.g., "34.00 - 34.01")
        if pd.isna(lat_band):
            lat_band_str = "Unknown Lat"
        else:
            lat_band_str = f"{lat_band.left:.2f} - {lat_band.right:.2f}"
            
        values_dict = {}
        for lon_band, count in row.items():
            if pd.isna(lon_band):
                lon_band_str = "Unknown Lon"
            else:
                lon_band_str = f"{lon_band.left:.2f}" # Using just the left bound for simplicity
            values_dict[lon_band_str] = int(count)

        # Filter out rows with no crime data
        if any(v > 0 for v in values_dict.values()):
            output_grid.append({
                "lat_band": lat_band_str,
                "values": values_dict
            })
    
    # Sort output grid by latitude band for consistent display
    output_grid.sort(key=lambda x: float(x['lat_band'].split(' ')[0]))

    return {"grid": output_grid}

@app.get("/api/time_of_day")
def get_time_of_day()-> dict[str, int]:
    """
    Calculates the distribution of crimes by time of day into 3-hour buckets.
    Returns a dictionary where keys are time buckets (e.g., "0-3") and values are crime counts.
    """
    df_local = df.copy()

    # Ensure 'time' column exists and is parsed to extract hours
    # The preprocess_data.py script already creates an 'hour' column
    if 'hour' not in df_local.columns:
        # Fallback if 'hour' not preprocessed (though it should be)
        df_local['time'] = pd.to_datetime(df_local['time'], format='%H%M', errors='coerce').dt.time
        df_local['hour'] = df_local['time'].apply(lambda t: t.hour if pd.notna(t) else np.nan)
        df_local.dropna(subset=['hour'], inplace=True)
    
    if df_local.empty:
        return {} # Return empty if no valid hour data

    # Define the 3-hour buckets
    bins = [0, 3, 6, 9, 12, 15, 18, 21, 24]
    labels = [
        "0-3", "3-6", "6-9", "9-12",
        "12-15", "15-18", "18-21", "21-24"
        ]

    # Use pd.cut to categorize hours into buckets
    df_local['hour_bucket'] = pd.cut(
        df_local['hour'],
        bins=bins,
        labels=labels,
        right=False, # Interval is [start, end)
        include_lowest=True
    )

    # Count crimes per bucket
    time_counts = df_local['hour_bucket'].value_counts().sort_index()

    # Convert to dictionary, ensuring all labels are present with 0 if no crimes
    hour_buckets = {label: 0 for label in labels}
    for label, count in time_counts.items():
        if label is not np.nan: # Exclude any unbinned NaNs
            hour_buckets[label] = int(count)

    return hour_buckets

# Define a Pydantic model for the sequence mining request parameters
class SequenceMiningRequest(BaseModel):
    min_support: float = 0.01
    time_window_hours: int = 24
    grouping_method: str = 'spatial_temporal'
    area_col: Optional[str] = None # Optional, will default to 'area_name' if needed

# Change this from @app.get to @app.post and update parameters
@app.post("/api/crime_sequences")
def post_crime_sequences(request: SequenceMiningRequest):
    """
    Run crime sequence mining algo from sequence_mining.py with configurable parameters.
    """
    try:
        df_local = df.copy()

        # Handle area_col if grouping_method is 'area_based'
        effective_area_col = request.area_col
        if request.grouping_method == "area_based":
            if effective_area_col is None:
                # Assuming 'area_name' is the default column for area-based grouping
                effective_area_col = 'area_name'
                # Check if 'area_name' exists in the DataFrame
                if effective_area_col not in df_local.columns:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Grouping method 'area_based' requires an area_col. "
                               "Default 'area_name' not found, please specify one."
                    )
            elif effective_area_col not in df_local.columns:
                raise HTTPException(
                    status_code=400,
                    detail=f"Specified area_col '{effective_area_col}' not found in data."
                )
        
        if df_local.empty:
            raise HTTPException(status_code=404, detail="Crime dataset is empty.")

        result = run_crime_sequence_mining(
            df_local,
            min_support=request.min_support,
            time_window_hours=request.time_window_hours,
            area_col=effective_area_col, # Pass the resolved area_col
            grouping_method=request.grouping_method,
            max_patterns=50, # Keeping this fixed for now, can be made configurable
        )
        
        return result

    except Exception as e:
        print(f"ERROR in /api/crime_sequences: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))
                    
@app.get("/api/crime_sequences")
def get_crime_sequences(
    min_support: float = 0.01,
    time_window_hours: int = 24,
    area_col: str = "area_name",
    grouping_method: str = "spatial_temporal",
    max_patterns: int = 50,
):
    """
    Run crime sequence mining algo from sequence_mining.py.
    """
    try:
        df_local=df.copy()
        if grouping_method == "area_based" and area_col not in df_local.columns:
            raise HTTPException(
                status_code=400,
                detail=f"Grouping method '{grouping_method}' requires '{area_col}' column, but it's missing."
            )
        if df_local.empty:
            raise HTTPException(status_code=404, detail="Crime dataset is empty.")

        result = run_crime_sequence_mining(
            df_local,
            min_support=min_support,
            time_window_hours=time_window_hours,
            area_col=area_col,
            grouping_method=grouping_method,
            max_patterns=max_patterns,
        )

        return result

    except Exception as e:
        print(f"ERROR in /api/crime_sequences: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))
