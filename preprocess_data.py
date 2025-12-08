"""
Crime Hotspot Data Preprocessing
"""

import pandas as pd
import numpy as np
from datetime import datetime
import os
import sys 

USING_KAGGLEHUB = True  # Set to False if using local CSV file

if USING_KAGGLEHUB:
    import kagglehub


stdout = sys.stdout
with open("summary.txt", "w") as f: 
    sys.stdout = f 


    ##### Download & Load Datasets
    print("\n")
    print("CRIME DATA PREPROCESSING")
    print("\n")

    def load_datasets():
        """Load datasets from KaggleHub or local files"""
        
        if USING_KAGGLEHUB:
            print("\nDOWNLOADING DATASETS FROM KAGGLE...")
            
            # Download Dataset: Crime Data from 2020 to Present
            try:
                path1 = kagglehub.dataset_download("ishajangir/crime-data")
                print("Path to dataset files:", path1)
                
                df1 = pd.read_csv(os.path.join(path1, "Crime_Data_from_2020_to_Present.csv"))
                print("LOADED DATASET 1")
            
            except Exception as e:
                print(f"Error with Dataset 1: {e}")
                df1 = None
            
            # Donwload Dataset: Crime and Safety Dataset
            try:
                path2 = kagglehub.dataset_download("shamimhasan8/crime-and-safety-dataset")
                print("Path to dataset files:", path2)

                df2 = pd.read_csv(os.path.join(path2, "crime_safety_dataset.csv"))
                print("LOADED DATASET 2")

            except Exception as e:
                print(f"Error with Dataset 2: {e}")
                df2 = None
        
        else:
            print("\nLOADING DATASETS FROM LOCAL CSV FILES...")
            
            # would need to change path accordingly LOL
            try:
                df1 = pd.read_csv('Crime_Data_from_2020_to_Present.csv')
                print("LOADED DATASET 'Crime_Data_from_2020_to_Present.csv'")
            except FileNotFoundError:
                print("Dataset 'Crime_Data_from_2020_to_Present.csv' not found")
                df1 = None
            
            try:
                df2 = pd.read_csv('crime_and_safety_dataset.csv')
                print("LOADED DATASET 'crime_and_safety_dataset.csv'")

            except FileNotFoundError:
                print("Dataset 'crime_and_safety_dataset.csv' not found")
                df2 = None
        
        return df1, df2

    df1, df2 = load_datasets()


    ##### Helper Function (i'm referencing main.py)
    def get_season(month):
        
        # Get season from the month number (from main.py) 
        if month in [12, 1, 2]:
            return 'Winter'
        elif month in [3, 4, 5]:
            return 'Spring'
        elif month in [6, 7, 8]:
            return 'Summer'
        else:  # 9, 10, 11
            return 'Fall'


    ##### Preprocess Dataset 1 (Crime Data from 2020 to Present)
    print("\n")
    print("PREPROCESSING DATASET 1: Crime Data from 2020 to Present")
    print("\n")

    if df1 is not None:
        print("\nOriginal shape: ", df1.shape)
        print(f"Columns: {df1.columns.tolist()[:10]}...")  # showing first 10 columns
        print(f"\nMissing values:\n{df1.isnull().sum().head(10)}")
        
        # Relevant columns
        date_col = next((col for col in df1.columns if 'DATE' in col.upper() and 'OCC' in col.upper()), None)
        time_col = next((col for col in df1.columns if 'TIME' in col.upper() and 'OCC' in col.upper()), None)
        lat_col = next((col for col in df1.columns if col.upper() == 'LAT'), None)
        lon_col = next((col for col in df1.columns if col.upper() == 'LON'), None)
        crime_col = next((col for col in df1.columns if 'CRM' in col.upper() and 'DESC' in col.upper()), None)
        weapon_col = next((col for col in df1.columns if 'WEAPON' in col.upper()), None)
        area_col = next((col for col in df1.columns if col.upper() == 'AREA'), None)
        area_name_col = next((col for col in df1.columns if 'AREA' in col.upper() and 'NAME' in col.upper()), None)
        premis_col = next((col for col in df1.columns if 'PREMIS' in col.upper()), None)
        
        print("COLUMNS:")
        print("Date: ", date_col)
        print("Time: ", time_col)
        print(f"Location: {lat_col}, {lon_col}")
        print("Crime: ", crime_col)
        print("Weapon: ", weapon_col)
        
        cols_to_keep = [col for col in [date_col, time_col, lat_col, lon_col, 
                                        crime_col, weapon_col, area_col, 
                                        area_name_col, premis_col] if col is not None]
        
        df1_clean = df1[cols_to_keep].copy()
        


        # rows with missing values -- remove them
        critical_col = [col for col in [date_col, time_col, lat_col, lon_col, crime_col] 
                        if col is not None]
        ini_len = len(df1_clean)
        df1_clean = df1_clean.dropna(subset=critical_col)
        len_diff = ini_len - len(df1_clean)
        print(f"\nRemoved {len_diff:,} rows.")
        

        # date --> datetime
        if date_col:
            df1_clean[date_col] = pd.to_datetime(df1_clean[date_col], errors='coerce')
            df1_clean = df1_clean.dropna(subset=[date_col])
            
            df1_clean = df1_clean.rename(columns={date_col: 'date'})
            date_col = 'date'
        
        # time --> proper format
        if time_col:
            df1_clean[time_col] = df1_clean[time_col].astype(str).str.zfill(4)
            df1_clean['hour'] = df1_clean[time_col].str[:2].astype(int)
            df1_clean['minute'] = df1_clean[time_col].str[2:].astype(int)
            
            df1_clean = df1_clean.rename(columns={time_col: 'time'})
        

        # normalizing long & lat values
        # getting rid of (0,0) coordinates
        if lat_col and lon_col:
            df1_clean = df1_clean[(df1_clean[lat_col] != 0) & (df1_clean[lon_col] != 0)]
            
            df1_clean['lat_norm'] = (df1_clean[lat_col] - df1_clean[lat_col].min()) / \
                                        (df1_clean[lat_col].max() - df1_clean[lat_col].min())
            
            df1_clean['lon_norm'] = (df1_clean[lon_col] - df1_clean[lon_col].min()) / \
                                        (df1_clean[lon_col].max() - df1_clean[lon_col].min())
            
            df1_clean = df1_clean.rename(columns={lat_col: 'latitude', lon_col: 'longitude'})
        

        if crime_col:
            df1_clean = df1_clean.rename(columns={crime_col: 'crime_type'})
        
        # saeson atttribute
        df1_clean['season'] = df1_clean['date'].dt.month.apply(get_season)
        
        # weapons_used binary 
        if weapon_col:
            df1_clean['weapon_used'] = df1_clean[weapon_col].notna().astype(int)
            df1_clean = df1_clean.rename(columns={weapon_col: 'weapon_description'})

        else:
            df1_clean['weapon_used'] = 0
        
        # temporal attributes
        df1_clean['year'] = df1_clean['date'].dt.year
        
        df1_clean['month'] = df1_clean['date'].dt.month
        
        df1_clean['day_of_week'] = df1_clean['date'].dt.dayofweek  # note: 0 = Monday and 6 = Sunday
        
        df1_clean['is_weekend'] = (df1_clean['day_of_week'] >= 5).astype(int)
        
        df1_clean['time_period'] = pd.cut(df1_clean['hour'], 
                                        bins=[0, 6, 12, 18, 24],
                                        labels=['Night', 'Morning', 'Afternoon', 'Evening'],
                                        include_lowest=True)
        
        print(f"\n Dataset 1 shape: {df1_clean.shape}")
        print(f"Date: {df1_clean['date'].min().date()} to {df1_clean['date'].max().date()}")
        print(f"\nSeasons:\n{df1_clean['season'].value_counts()}")
        print(f"\nWeapons: {df1_clean['weapon_used'].sum():,} crimes with weapons ({df1_clean['weapon_used'].mean()*100:.1f}%)")
        print(f"\nTop crime types:\n{df1_clean['crime_type'].value_counts().head()}")

    else:
        df1_clean = None
        print("\nDataset 1 NOT FOUND.")



    ##### Preprocess Dataset 2 (Crime and Safety Dataset)
    print("\n")
    print("PREPROCESSING DATASET 2: Crime and Safety Dataset")
    print("\n")

    if df2 is not None:
        print(f"\nOriginal shape: {df2.shape}")
        print(f"Columns: {df2.columns.tolist()}")
        
        # date --> datetime
        if 'date' in df2.columns:
            df2['date'] = pd.to_datetime(df2['date'], errors='coerce')
            df2 = df2.dropna(subset=['date'])
        
        # season attribute
        if 'date' in df2.columns:
            df2['season'] = df2['date'].dt.month.apply(get_season)
        
        # temporal attritbutes
        if 'date' in df2.columns:
            df2['year'] = df2['date'].dt.year
            df2['month'] = df2['date'].dt.month
            df2['day_of_week'] = df2['date'].dt.dayofweek
            df2['is_weekend'] = (df2['day_of_week'] >= 5).astype(int)
        
        # wweapon_used
        if 'weapon_used' not in df2.columns:
            weapon_cols = [col for col in df2.columns if 'weapon' in col.lower()]
            if weapon_cols:
                df2['weapon_used'] = df2[weapon_cols[0]].notna().astype(int)
            else:
                df2['weapon_used'] = 0  # Default to 0 if no weapon info
        
        print(f"\n Final Dataset 2 shape: {df2.shape}")
        if 'date' in df2.columns:
            print(f"Date: {df2['date'].min().date()} to {df2['date'].max().date()}")
            print(f"\nSeasons:\n{df2['season'].value_counts()}")

    else:
        print("\nDataset 2 NOT FOUND.")


    ##### Save Cleaned Datasets

    print("\n")
    print("SAVING CLEANED DATASETS")
    print("\n")

    if df1_clean is not None:
        output_file = "crime_data_cleaned.csv"  # to be used in main.py
        df1_clean.to_csv(output_file, index=False)
        size_mb = df1_clean.memory_usage(deep=True).sum() / 1024**2
        
        print("\n Processed dataset 1 saved as: ", output_file)
        print(f"  Records: {len(df1_clean):,}")
        print(f"  Size: {size_mb:.2f} MB")
        print(f"  Columns: {list(df1_clean.columns)}")

    if df2 is not None:
        output_file_2 = "crime_safety_cleaned.csv"
        df2.to_csv(output_file_2, index=False)
        print("\n Processed dataset 2 saved as: ", output_file_2)
        print(f"  Records: {len(df2):,}")

    ##### Summary for Dataset 1 
    print("\n")
    print("SUMMARY: DATASET 1")
    print("\n")

    if df1_clean is not None:
        print("\n METRICS")
        print(f"Total records after cleaning: {len(df1_clean):,}")
        print(f"Date range: {df1_clean['date'].min().date()} to {df1_clean['date'].max().date()}")
        print(f"Unique crime types: {df1_clean['crime_type'].nunique()}")
        print(f"Crimes with weapons: {df1_clean['weapon_used'].sum():,} ({df1_clean['weapon_used'].mean()*100:.1f}%)")
        
        print("\n SEASONAL")
        season_counts = df1_clean['season'].value_counts()
        for season in ['Winter', 'Spring', 'Summer', 'Fall']:
            if season in season_counts.index:
                count = season_counts[season]
                pct = (count / len(df1_clean)) * 100
                print(f"{season:8s}: {count:7,} crimes ({pct:5.2f}%)")
        
        print("\n TOP CRIME ")
        top_crimes = df1_clean['crime_type'].value_counts().head(10)
        for i, (crime, count) in enumerate(top_crimes.items(), 1):
            pct = (count / len(df1_clean)) * 100
            print(f"{i:2d}. {crime[:50]:50s} {count:6,} ({pct:5.2f}%)")
        
        print("\n TEMPORAL ")
        print(f"Weekend crimes: {df1_clean['is_weekend'].sum():,} ({df1_clean['is_weekend'].mean()*100:.1f}%)")
        print("\nCrimes by time period:")
        print(df1_clean['time_period'].value_counts().sort_index())
        
        print("\n DATA QUALITY ")
        print(f"Records with valid coordinates: {len(df1_clean):,}")
        print(f"Records with weapon info: {df1_clean['weapon_used'].sum():,}")
        print(f"Complete records (no missing values): {df1_clean.notna().all(axis=1).sum():,}")


    ##### SUMMARY FOR DATASET 2
    print("\n")
    print("SUMMARY: DATASET 2")
    print("\n")

    if df2 is not None:

        print("\n METRICS")
        print(f"Total records: {len(df2):,}")

        print("\n Date Range") 
        print(f"Date range: {df2['date'].min().date()} to {df2['date'].max().date()}")

        print("\n Crime Types")
        print(f"Unique crime types: {df2['crime_type'].nunique()}")
        top_crimes_2 = df2['crime_type'].value_counts().head(10)

        print("\n Weapon Usage")
        if 'weapon_used' in df2.columns:
            print(f"Crimes with weapons: {df2['weapon_used'].sum():,} "
                f"({df2['weapon_used'].mean()*100:.1f}%)")

        print("\n SEASONAL")
        season_counts_2 = df2['season'].value_counts()
        for season in ['Winter', 'Spring', 'Summer', 'Fall']:
            if season in season_counts_2.index:
                count = season_counts_2[season]
                pct = (count / len(df2)) * 100
                print(f"{season:8s}: {count:7,} crimes ({pct:5.2f}%)")

        print("\n TEMPORAL")
        print(f"Weekend crimes: {df2['is_weekend'].sum():,} "
            f"({df2['is_weekend'].mean()*100:.1f}%)")

        print("\n Crimes by day of week (0=Mon, 6=Sun):")
        print(df2['day_of_week'].value_counts().sort_index())

        print("\n Crimes by month:")
        print(df2['month'].value_counts().sort_index())

        if 'time' in df2.columns:
            df2['hour'] = pd.to_datetime(df2['time'], format="%H:%M:%S",
                                        errors='coerce').dt.hour
            df2['time_period'] = pd.cut(df2['hour'],
                                        bins=[0,6,12,18,24],
                                        labels=['Night','Morning','Afternoon','Evening'],
                                        include_lowest=True)

            print("\n Crimes by time period:")
            print(df2['time_period'].value_counts().sort_index())

        print("\n TOP CRIME TYPES")
        for i, (crime, count) in enumerate(top_crimes_2.items(), 1):
            pct = (count / len(df2)) * 100
            print(f"{i:2d}. {crime[:40]:40s} {count:6,} ({pct:5.2f}%)")

        print("\n DATA QUALITY")
        print(f"Complete records (no missing values): {df2.notna().all(axis=1).sum():,}")
        
        print("\n CRIME BY GENDER")
        if 'victim_gender' in df2.columns:
            print("\nCrimes by victim gender:")
            print(df2['victim_gender'].value_counts())

        print("\n CRIME BT RACE")
        if 'victim_race' in df2.columns:
            print("\nCrimes by victim race:")
            print(df2['victim_race'].value_counts())

        print("\n CRIME BY STATE")
        if 'state' in df2.columns:
            print("\nTop states by crime count:")
            print(df2['state'].value_counts().head(10))

        print("\n CRIME BY CITY")
        if 'city' in df2.columns:
            print("\nTop cities by crime count:")
            print(df2['city'].value_counts().head(10))

        if 'victim_age' in df2.columns:
            df2['age_group'] = pd.cut(
                df2['victim_age'],
                bins=[0,12,18,30,50,80,120],
                labels=['Child','Teen','Young Adult','Adult','Middle Age','Senior']
            )

            print("\nCrimes by victim age group:")
            print(df2['age_group'].value_counts())

    else:
        print("\nDataset 2 NOT FOUND.")



    print("\n")
    print("DATA PREPROCESSING COMPLETED.")

sys.stdout = stdout
print("Results saved to summary.txt")