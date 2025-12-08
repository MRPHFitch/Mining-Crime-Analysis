from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
from scipy.stats import chi2_contingency
from typing import Optional
from kmeans import run_hotspot_kmeans

app = FastAPI()

# Load your dataset (FIX PATH)
df = pd.read_csv('../crime_data_cleaned.csv')

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
    df['date'] = pd.to_datetime(df['date'])
    df['season'] = df['date'].dt.month.apply(get_season)
    # Group by season and crime_type, count occurrences
    season_crime = df.groupby(['season', 'crime_type']).size().reset_index(name='count')
    # Group by season and weapon used, count occurrences
    if 'weapon_used' in df.columns:
        season_weapon = df.groupby(['season', 'weapon_used']).size().reset_index(name='count')
    else:
        season_weapon = []
    return {
        "season_crime": season_crime.to_dict(orient='records'),
        "season_weapon": season_weapon if isinstance(season_weapon, list) else season_weapon.to_dict(orient='records')
    }
    
@app.get("/api/season_analysis")
def season_analysis():
    dfLocal=df.copy()
    # Add season column
    dfLocal['date'] = pd.to_datetime(df['date'])
    dfLocal['season'] = df['date'].dt.month.apply(get_season)
    if dfLocal.empty:
        return {"error: Dataset is empty."}
    if len(dfLocal)<10:
        return {"error: Not large enough for Apriori."}
    
    # --- Apriori Algorithm ---
    # Prepare data for Apriori (one-hot encoding)
    apriori_df = dfLocal[['season', 'crime_type', 'weapon_used']].astype(str)
    onehot = pd.get_dummies(apriori_df)
    frequent_itemsets = apriori(onehot, min_support=0.05, use_colnames=True)
    rules = association_rules(frequent_itemsets, metric="lift", min_threshold=1)
    #Sort by the strongest association first
    rules=rules.sort_values(by='lift', ascending=False)
    
    #Extract the Top 5 rules
    top5=apriori_results.head(5).copy()
    top5['antecedents']=top5['antecedents'].apply(lambda x: list(x))
    top5['consequents']=top5['consequents'].apply(lambda x: list(x))
    top5=top5.to_dict(orient='records')
    
    # Simplify rules for output
    apriori_results = rules[['antecedents', 'consequents', 'support', 'confidence', 'lift']].copy()
    apriori_results['antecedents'] = apriori_results['antecedents'].apply(lambda x: list(x))
    apriori_results['consequents'] = apriori_results['consequents'].apply(lambda x: list(x))
    apriori_results = apriori_results.to_dict(orient='records')
    
    # --- Annotate each rule with chi-square ---
    def parse_onehot(colval):
        # e.g., "season_Summer" -> ("season", "Summer")
        col, val = colval.split("_", 1)
        return (col, val)

    for rule in apriori_results:
        # Only handle single antecedent/consequent for chi-square (extend as needed)
        if len(rule['antecedents']) == 1 and len(rule['consequents']) == 1:
            antecedent = parse_onehot(rule['antecedents'][0])
            consequent = parse_onehot(rule['consequents'][0])
            chi2, p = chi_square_for_rule(df, antecedent, consequent)
            rule['chi2'] = chi2
            rule['p_value'] = p
        else:
            rule['chi2'] = None
            rule['p_value'] = None

    # --- Chi-square Test: Season vs Crime Type ---
    contingency1 = pd.crosstab(df['season'], df['crime_type'])
    chi2_1, p_1, _, _ = chi2_contingency(contingency1)

    # --- Chi-square Test: Season vs Weapon Used ---
    if 'weapon_used' in df.columns:
        contingency2 = pd.crosstab(df['season'], df['weapon_used'])
        chi2_2, p_2, _, _ = chi2_contingency(contingency2)
    else:
        chi2_2, p_2 = None, None
        
    # --- Prepare Chart Data for Frontend ---
    #Global relationships (heatmap-like data)
    contingency1 = pd.crosstab(df['season'], df['crime_type'])
    season_crime_chart = [{
            "season": season,
            "crime_counts": contingency1.loc[season].to_dict()
        }
        for season in contingency1.index
    ]

    if 'weapon_used' in df.columns:
        contingency2 = pd.crosstab(df['season'], df['weapon_used'])
        season_weapon_chart = [{
                "season": season,
                "weapon_counts": contingency2.loc[season].to_dict()
        }
        for season in contingency2.index
        ]
    else:
        season_weapon_chart = []

    #Top 5 Apriori rules for bar chart
    top_df = pd.DataFrame(top5)
    top_df['rule_label'] = top_df.apply(
        lambda r: f"{', '.join(r['antecedents'])} → {', '.join(r['consequents'])}", axis=1
    )
    top_rules_chart = [
        {"rule": row["rule_label"], "lift": row["lift"], "confidence": row["confidence"]}
        for _, row in top_df.iterrows()
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
    
def chi_square_for_rule(df, antecedent, consequent):
    # Both antecedent and consequent are lists of column=value pairs
    mask_a = df[antecedent[0]] == antecedent[1]
    mask_c = df[consequent[0]] == consequent[1]
    table = pd.crosstab(mask_a, mask_c)
    if table.shape ==(2,2) and (table.values==0).any():
        return None, None
    if mask_a.nunique()<2 or mask_c.nunique()<2:
        return None, None
    chi2, p, _, _ = chi2_contingency(table)
    return chi2, p
