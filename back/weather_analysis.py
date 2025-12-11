import pandas as pd
from scipy.stats import chi2_contingency
from mlxtend.frequent_patterns import apriori, association_rules
from typing import Dict, Any, Optional

# Helper function for season (also used in preprocess_data.py)
def get_season(month: int) -> str:
    if month in [12, 1, 2]:
        return 'Winter'
    elif month in [3, 4, 5]:
        return 'Spring'
    elif month in [6, 7, 8]:
        return 'Summer'
    else:
        return 'Fall'

# Helper function to parse one-hot encoded item strings
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
        return (item_string, True) # Potentially risky, consider error handling

# Helper function for Chi-square test
def chi_square_for_rule(df_local_param: pd.DataFrame, antecedent: tuple, consequent: tuple) -> tuple[Optional[float], Optional[float]]:
    # Both antecedent and consequent are tuples of (column_name, value)
    mask_a = df_local_param[antecedent[0]] == antecedent[1]
    mask_c = df_local_param[consequent[0]] == consequent[1]
    table = pd.crosstab(mask_a, mask_c)
    # More robust check for valid table for chi2
    if table.shape != (2,2) or (table.values==0).any():
        return None, None
    # Check if there's enough variation for chi2_contingency
    if len(mask_a.unique()) < 2 or len(mask_c.unique()) < 2:
        return None, None
    chi2, p, _, _ = chi2_contingency(table)
    return float(chi2), float(p)

def run_seasonal_analysis(df: pd.DataFrame) -> Dict[str, Any]:
    """
    Performs seasonal crime analysis including Apriori algorithm and Chi-square tests.
    """
    dfLocal = df.copy() # Work on a copy of the input DataFrame
    
    # Add season column
    dfLocal['date'] = pd.to_datetime(dfLocal['date'])
    dfLocal['season'] = dfLocal['date'].dt.month.apply(get_season)
    
    if dfLocal.empty:
        raise ValueError("Dataset is empty after date processing.")
    if len(dfLocal) < 10: # Minimum records for Apriori and meaningful stats
        raise ValueError("Dataset not large enough for Apriori (min 10 rows recommended).")
    
    # --- Apriori Algorithm ---
    # Prepare data for Apriori (one-hot encoding)
    cols_for_apriori = []
    if 'season' in dfLocal.columns: cols_for_apriori.append('season')
    if 'crime_type' in dfLocal.columns: cols_for_apriori.append('crime_type')
    if 'weapon_used' in dfLocal.columns: cols_for_apriori.append('weapon_used')

    if not cols_for_apriori:
        raise ValueError('No relevant columns found for Apriori analysis.')

    apriori_df = dfLocal[cols_for_apriori].astype(str)
    onehot = pd.get_dummies(apriori_df)
    
    if onehot.empty:
        raise ValueError('No suitable data for Apriori after encoding.')
    
    frequent_itemsets_df = pd.DataFrame()
    rules_df = pd.DataFrame()
    apriori_results = []
    top5 = []

    frequent_itemsets_df = apriori(onehot, min_support=0.05, use_colnames=True)
    if frequent_itemsets_df.empty:
        raise ValueError('No frequent item sets with min_support=0.05. Consider lowering it or checking data.')
        
    rules_df = association_rules(frequent_itemsets_df, metric="lift", min_threshold=1)
    if rules_df.empty:
        # It's possible to have no rules with min_threshold=1,
        # but let's make sure it doesn't cause a crash later if apriori_results is empty
        pass
    else:
        rules_df = rules_df.sort_values(by='lift', ascending=False)
        processed_rules_df = rules_df[['antecedents', 'consequents', 'support', 'confidence', 'lift']].copy()
        processed_rules_df['antecedents'] = processed_rules_df['antecedents'].apply(lambda x: list(x))
        processed_rules_df['consequents'] = processed_rules_df['consequents'].apply(lambda x: list(x))
        
        apriori_results = processed_rules_df.to_dict(orient='records')
        top5_df = processed_rules_df.head(5).copy()
        top5 = top5_df.to_dict(orient='records')
    
    # --- Annotate each rule with chi-square ---
    for rule in apriori_results:
        if len(rule['antecedents']) == 1 and len(rule['consequents']) == 1:
            antecedent_str = rule['antecedents'][0]
            consequent_str = rule['consequents'][0]
            
            antecedent = parse_onehot(antecedent_str)
            consequent = parse_onehot(consequent_str)
            
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
        chi2_1 = float(chi2_1)
        p_1 = float(p_1)

    # --- Chi-square Test: Season vs Weapon Used ---
    chi2_2, p_2 = None, None
    season_weapon_chart = []
    if 'weapon_used' in dfLocal.columns:
        contingency2 = pd.crosstab(dfLocal['season'], dfLocal['weapon_used'])
        if not contingency2.empty and contingency2.shape[0] > 1 and contingency2.shape[1] > 1:
            chi2_2, p_2, _, _ = chi2_contingency(contingency2)
            chi2_2 = float(chi2_2)
            p_2 = float(p_2)
            season_weapon_chart = [{
                "season": season,
                "weapon_counts": contingency2.loc[season].to_dict()
                }
                for season in contingency2.index
            ]
            
    # --- Prepare Chart Data for Frontend ---
    season_crime_chart = []
    if not contingency1.empty:
        season_crime_chart = [{
                "season": season,
                "crime_counts": contingency1.loc[season].to_dict()
            }
            for season in contingency1.index
        ]

    top_rules_chart = []
    if top5:
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