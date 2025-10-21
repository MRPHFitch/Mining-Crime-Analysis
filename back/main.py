from fastapi import FastAPI
import pandas as pd
from scipy.stats import chi2_contingency

app = FastAPI()

# Load your dataset (FIX PATH)
df = pd.read_csv('crime_data.csv')


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
    # Add season column
    df['date'] = pd.to_datetime(df['date'])
    df['season'] = df['date'].dt.month.apply(get_season)
    
    # --- Apriori Algorithm ---
    # Prepare data for Apriori (one-hot encoding)
    apriori_df = df[['season', 'crime_type', 'weapon_used']].astype(str)
    onehot = pd.get_dummies(apriori_df)
    frequent_itemsets = apriori(onehot, min_support=0.05, use_colnames=True)
    rules = association_rules(frequent_itemsets, metric="lift", min_threshold=1)
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

    return {
        "apriori_rules": apriori_results,
        "chi_square": {
            "season_vs_crime_type": {"chi2": chi2_1, "p_value": p_1},
            "season_vs_weapon_used": {"chi2": chi2_2, "p_value": p_2}
        }
    }
    
def chi_square_for_rule(df, antecedent, consequent):
    # Both antecedent and consequent are lists of column=value pairs
    mask_a = df[antecedent[0]] == antecedent[1]
    mask_c = df[consequent[0]] == consequent[1]
    table = pd.crosstab(mask_a, mask_c)
    chi2, p, _, _ = chi2_contingency(table)
    return chi2, p