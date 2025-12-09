from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
import numpy as np
from scipy.stats import chi2_contingency
from typing import Optional
from kmeans import run_hotspot_kmeans
from mlxtend.frequent_patterns import apriori, association_rules

app = FastAPI()

# Load your dataset (FIX PATH)
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

# Define parse_onehot function globally (with fix)
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
                                   # Consider handling this case as an error if it shouldn't happen.

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
    df_local_seasons['date'] = pd.to_datetime(df_local_seasons['date']) # Use df_local_seasons
    df_local_seasons['season'] = df_local_seasons['date'].dt.month.apply(get_season) # Use df_local_seasons
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

@app.get("/api/weather_analysis")
def weather_analysis():
    dfLocal = df.copy() # Use a local copy
    # Add season column
    dfLocal['date'] = pd.to_datetime(dfLocal['date'])
    dfLocal['season'] = dfLocal['date'].dt.month.apply(get_season)
    
    if dfLocal.empty:
        raise HTTPException(status_code=400, detail="Dataset is empty after date processing.")
    if len(dfLocal) < 10: # Minimum records for Apriori and meaningful stats
        raise HTTPException(status_code=400, detail="Dataset not large enough for Apriori (min 10 rows recommended).")
    
    # --- Apriori Algorithm ---
    # Prepare data for Apriori (one-hot encoding)
    # Ensure all columns exist before selecting
    cols_for_apriori = []
    if 'season' in dfLocal.columns: cols_for_apriori.append('season')
    if 'crime_type' in dfLocal.columns: cols_for_apriori.append('crime_type')
    if 'weapon_used' in dfLocal.columns: cols_for_apriori.append('weapon_used')

    if not cols_for_apriori:
        raise HTTPException(status_code=400, detail='No relevant columns found for Apriori analysis.')

    apriori_df = dfLocal[cols_for_apriori].astype(str)
    onehot = pd.get_dummies(apriori_df)
    
    if onehot.empty:
        raise HTTPException(status_code=400, detail='No suitable data for Apriori after encoding.')
    
    frequent_itemsets_df = pd.DataFrame()
    rules_df = pd.DataFrame()
    apriori_results = [] # Initialize as empty list for output
    top5 = [] # Initialize as empty list for output

    try:
        frequent_itemsets_df = apriori(onehot, min_support=0.05, use_colnames=True)
        if frequent_itemsets_df.empty:
            raise HTTPException(status_code=400, detail='No frequent item sets with min_support=0.05. Consider lowering it or checking data.')
            
        rules_df = association_rules(frequent_itemsets_df, metric="lift", min_threshold=1)
        if rules_df.empty:
            raise HTTPException(status_code=400, detail='No association rules found with min_threshold=1. Consider lowering it or checking data.')
        
        #Sort by the strongest association first
        rules_df = rules_df.sort_values(by='lift', ascending=False)
    
        # Simplify rules for output
        processed_rules_df = rules_df[['antecedents', 'consequents', 'support', 'confidence', 'lift']].copy()
        processed_rules_df['antecedents'] = processed_rules_df['antecedents'].apply(lambda x: list(x))
        processed_rules_df['consequents'] = processed_rules_df['consequents'].apply(lambda x: list(x))
        
        apriori_results = processed_rules_df.to_dict(orient='records')
      
        #Extract the Top 5 rules
        top5_df = processed_rules_df.head(5).copy() # Use processed_rules_df
        top5 = top5_df.to_dict(orient='records')
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Error during Apriori analysis: {e}.')
    
    # --- Annotate each rule with chi-square ---
    for rule in apriori_results:
        # Only handle single antecedent/consequent for chi-square
        if len(rule['antecedents']) == 1 and len(rule['consequents']) == 1:
            antecedent_str = rule['antecedents'][0]
            consequent_str = rule['consequents'][0]
            
            antecedent = parse_onehot(antecedent_str)
            consequent = parse_onehot(consequent_str)
            
            # Corrected: Pass dfLocal to chi_square_for_rule
            chi2, p = chi_square_for_rule(dfLocal, antecedent, consequent)
            rule['chi2'] = chi2
            rule['p_value'] = p
        else:
            rule['chi2'] = None
            rule['p_value'] = None

    # --- Chi-square Test: Season vs Crime Type ---
    contingency1 = pd.crosstab(dfLocal['season'], dfLocal['crime_type'])
    chi2_1, p_1 = None, None
    if not contingency1.empty and contingency1.shape[0] > 1 and contingency1.shape[1] > 1:
        chi2_1, p_1, _, _ = chi2_contingency(contingency1)

    # --- Chi-square Test: Season vs Weapon Used ---
    chi2_2, p_2 = None, None
    season_weapon_chart = []
    if 'weapon_used' in dfLocal.columns:
        contingency2 = pd.crosstab(dfLocal['season'], dfLocal['weapon_used'])
        if not contingency2.empty and contingency2.shape[0] > 1 and contingency2.shape[1] > 1:
            chi2_2, p_2, _, _ = chi2_contingency(contingency2)
            
    # --- Prepare Chart Data for Frontend ---
    #Global relationships (heatmap-like data)
    season_crime_chart = []
    if not contingency1.empty:
        season_crime_chart = [{
                "season": season,
                "crime_counts": contingency1.loc[season].to_dict()
            }
            for season in contingency1.index
        ]
    season_weapon_chart = [{
        "season": season,
        "weapon_counts": contingency2.loc[season].to_dict()
        }
        for season in contingency2.index
        ]

    #Top 5 Apriori rules for bar chart
    top_rules_chart = []
    if top5: # Check if top5 is not empty
        top_rules_chart = [
            {"rule": f"{', '.join(row['antecedents'])} \u2192 {', '.join(row['consequents'])}",
             "lift": row["lift"], "confidence": row["confidence"]}
            for row in top5
        ]

    return {
        "summary": {
            "n_records": len(dfLocal),
            "n_rules": len(apriori_results)
        },
        "apriori_rules": apriori_results,
        "top 5 rules": top5,
        "chi_square": {
            "season_vs_crime_type": {"chi2": chi2_1, "p_value": p_1},
            "season_vs_weapon_used": {"chi2": chi2_2, "p_value": p_2}
        },
        "charts": {
          "global_relationships": {
              "season_vs_crime_type": season_crime_chart,
              "season_vs_weapon_used": season_weapon_chart
          },
          "top_5_rules_chart": top_rules_chart
      }
    }
    
# Add a new endpoint to preview the cleaned data
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
    .head(20)
)
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
    lat_bin_size = .05 # e.g., ~1.11 km for lat
    lon_bin_size = .05 # e.g., ~0.9 km for lon at 34 deg latitude

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
                lon_band_str = f"{lon_band.left:.2f}" # Using just the left bound for simplicity, can adjust
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
    