# File: /Users/Phoo/Classes/Data Mining/Project/Mining-Crime-Analysis/back/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
from scipy.stats import chi2_contingency
from typing import Optional
from kmeans import run_hotspot_kmeans
# ADD THESE IMPORTS for Apriori functionality:
from mlxtend.frequent_patterns import apriori, association_rules

app = FastAPI()

# Load your dataset (FIX PATH)
df = pd.read_csv('../crime_data_cleaned.csv')
print(f"DEBUG: Initial DataFrame columns: {df.columns.tolist()}") # Debug print

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

@app.get("/api/season_analysis")
def season_analysis():
    dfLocal = df.copy() # Use a local copy
    # Add season column
    dfLocal['date'] = pd.to_datetime(dfLocal['date']) # Corrected: Use dfLocal for modification
    dfLocal['season'] = dfLocal['date'].dt.month.apply(get_season) # Corrected: Use dfLocal for modification
    print(f"DEBUG: dfLocal columns before Apriori: {dfLocal.columns.tolist()}") # Debug print
    
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
    
    frequent_itemsets_df = pd.DataFrame() # Use distinct name
    rules_df = pd.DataFrame() # Use distinct name
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
        print(f"DEBUG: Full apriori_results (first 3 rules): {apriori_results[:3]}") # Debug print
      
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
            print(f"DEBUG: Processing antecedent_str='{antecedent_str}', consequent_str='{consequent_str}'") # Debug print
            
            antecedent = parse_onehot(antecedent_str)
            consequent = parse_onehot(consequent_str)
            print(f"DEBUG: Parsed antecedent='{antecedent}', parsed consequent='{consequent}'") # Debug print
            
            # Corrected: Pass dfLocal to chi_square_for_rule
            chi2, p = chi_square_for_rule(dfLocal, antecedent, consequent)
            rule['chi2'] = chi2
            rule['p_value'] = p
        else:
            rule['chi2'] = None
            rule['p_value'] = None

    # --- Chi-square Test: Season vs Crime Type ---
    contingency1 = pd.crosstab(dfLocal['season'], dfLocal['crime_type']) # Use dfLocal
    chi2_1, p_1 = None, None
    if not contingency1.empty and contingency1.shape[0] > 1 and contingency1.shape[1] > 1:
        chi2_1, p_1, _, _ = chi2_contingency(contingency1)

    # --- Chi-square Test: Season vs Weapon Used ---
    chi2_2, p_2 = None, None
    season_weapon_chart = []
    if 'weapon_used' in dfLocal.columns: # Use dfLocal
        contingency2 = pd.crosstab(dfLocal['season'], dfLocal['weapon_used']) # Use dfLocal
        if not contingency2.empty and contingency2.shape[0] > 1 and contingency2.shape[1] > 1:
            chi2_2, p_2, _, _ = chi2_contingency(contingency2)
            season_weapon_chart = [{
                    "season": season,
                    "weapon_counts": contingency2.loc[season].to_dict()
            }
            for season in contingency2.index
            ]
        
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