import pandas as pd
import numpy as np
from typing import List, Dict, Tuple, Set, Optional
from collections import defaultdict
from datetime import timedelta


class PrefixSpan:
    
    def __init__(self, min_support: float = 0.01):
        self.min_support = min_support
        self.frequent_patterns = []
    
    # counts how many times a specific pattern appears across all the sequences 
    def _get_support_count(self, pattern: Tuple, sequences: List[List]) -> int:
        count = 0
        for seq in sequences:
            if self._is_subsequence(pattern, seq):
                count += 1
        return count
    
    # checks if pattern is subsequent to sequence 
    def _is_subsequence(self, pattern: Tuple, sequence: List) -> bool:
        if not pattern:
            return True
        
        pattern_idx = 0
        for item in sequence:
            if pattern_idx < len(pattern) and item == pattern[pattern_idx]:
                pattern_idx += 1
                if pattern_idx == len(pattern):
                    return True
        return False
    
    # finds all single items that meet  minimum frequency threshold
    def _get_frequent_items(self, sequences: List[List], min_count: int) -> List:
        item_counts = defaultdict(int)
        for seq in sequences:
            seen = set()
            for item in seq:
                if item not in seen:
                    item_counts[item] += 1
                    seen.add(item)
        
        return [item for item, count in item_counts.items() if count >= min_count]
    
    # when pattern is found, look at only the data immediately following pattern in dataset
    def _project_database(self, pattern: Tuple, sequences: List[List]) -> List[List]:
        projected = []
        
        for seq in sequences:
            # finding pattern in sequence
            pattern_idx = 0
            for i, item in enumerate(seq):
                if pattern_idx < len(pattern) and item == pattern[pattern_idx]:
                    pattern_idx += 1
                    if pattern_idx == len(pattern):

                        # found complete pattern, add suffix
                        if i + 1 < len(seq):
                            projected.append(seq[i+1:])
                        break
        
        return projected
    

    # recursively explores longer and longer sequences 
    def _prefixspan_recursive(self, pattern: Tuple, sequences: List[List], 
                             min_count: int, results: List):

        # get frequent items in projected database
        freq_items = self._get_frequent_items(sequences, min_count)
        
        for item in freq_items:
            new_pattern = pattern + (item,)
            support = self._get_support_count(new_pattern, sequences)
            
            if support >= min_count:
                results.append((new_pattern, support))
                
                projected = self._project_database(new_pattern, sequences)
                if projected:
                    self._prefixspan_recursive(new_pattern, projected, min_count, results)
    
    # cleans up the results, sorts them
    def fit(self, sequences: List[List]) -> List[Tuple]:
        if not sequences:
            return []
        
        min_count = max(1, int(self.min_support * len(sequences)))
        results = []
        
        # starting with frequent 1-items
        freq_items = self._get_frequent_items(sequences, min_count)
        
        for item in freq_items:
            pattern = (item,)
            support = self._get_support_count(pattern, sequences)
            results.append((pattern, support))
            
            # project and recurse
            projected = self._project_database(pattern, sequences)
            if projected:
                self._prefixspan_recursive(pattern, projected, min_count, results)
        
        self.frequent_patterns = sorted(results, key=lambda x: (-x[1], -len(x[0])))
        return self.frequent_patterns


def prepare_crime_sequences(
    df: pd.DataFrame,
    *,
    time_window_hours: int = 24,
    area_col: Optional[str] = None,
    grouping_method: str = 'spatial_temporal'
) -> Tuple[List[List], pd.DataFrame]:

    df_work = df.copy()
    
    # datetime
    if 'date' in df_work.columns:
        df_work['date'] = pd.to_datetime(df_work['date'], errors='coerce')
    
    # Create full datetime if we have time
    if 'time' in df_work.columns and 'hour' in df_work.columns:
        df_work['datetime'] = df_work['date'] + pd.to_timedelta(df_work['hour'], unit='h')
    else:
        df_work['datetime'] = df_work['date']
    
    # Sort by datetime
    df_work = df_work.sort_values('datetime').reset_index(drop=True)
    
    sequences = []
    sequence_metadata = []
    
    # define how crimes are grouped into a single "sequence"
    # temporal_only: groups crimes based on if occurred within  time_window_hours of  previous crime (regardless of location) 
    # area_based: groups crimes that occur within geographical area and within time window 
    # spatial_temporal: default. groups crimes spatially close & temporally close (within  time_window_hours)
    
    if grouping_method == 'temporal_only':
        
        # groups all nearby crimes by time window regardless of location
        current_seq = []
        seq_start_time = None
        seq_crimes = []
        
        for idx, row in df_work.iterrows():
            crime_type = row.get('crime_type', 'UNKNOWN')
            crime_time = row['datetime']
            
            if seq_start_time is None or (crime_time - seq_start_time) <= timedelta(hours=time_window_hours):
                current_seq.append(crime_type)
                seq_crimes.append(idx)
                if seq_start_time is None:
                    seq_start_time = crime_time
            else:
                # Save current sequence and start new one
                if len(current_seq) >= 2:  # Only keep sequences with 2+ crimes
                    sequences.append(current_seq)
                    sequence_metadata.append({
                        'seq_id': len(sequences),
                        'length': len(current_seq),
                        'start_time': seq_start_time,
                        'crime_indices': seq_crimes
                    })
                current_seq = [crime_type]
                seq_crimes = [idx]
                seq_start_time = crime_time
        
        # Add last sequence
        if len(current_seq) >= 2:
            sequences.append(current_seq)
            sequence_metadata.append({
                'seq_id': len(sequences),
                'length': len(current_seq),
                'start_time': seq_start_time,
                'crime_indices': seq_crimes
            })
    
    # groups by a specific area ID 
    elif grouping_method == 'area_based' and area_col and area_col in df_work.columns:
        # Group by area, create sequences within each area
        for area, area_df in df_work.groupby(area_col):
            area_df = area_df.sort_values('datetime')
            current_seq = []
            seq_start_time = None
            seq_crimes = []
            
            for idx, row in area_df.iterrows():
                crime_type = row.get('crime_type', 'UNKNOWN')
                crime_time = row['datetime']
                
                if seq_start_time is None or (crime_time - seq_start_time) <= timedelta(hours=time_window_hours):
                    current_seq.append(crime_type)
                    seq_crimes.append(idx)
                    if seq_start_time is None:
                        seq_start_time = crime_time
                else:
                    if len(current_seq) >= 2:
                        sequences.append(current_seq)
                        sequence_metadata.append({
                            'seq_id': len(sequences),
                            'area': area,
                            'length': len(current_seq),
                            'start_time': seq_start_time,
                            'crime_indices': seq_crimes
                        })
                    current_seq = [crime_type]
                    seq_crimes = [idx]
                    seq_start_time = crime_time
            
            if len(current_seq) >= 2:
                sequences.append(current_seq)
                sequence_metadata.append({
                    'seq_id': len(sequences),
                    'area': area,
                    'length': len(current_seq),
                    'start_time': seq_start_time,
                    'crime_indices': seq_crimes
                })
    
    else:  # spatial_temporal
        # Use lat/lon clustering for spatial proximity
        if 'latitude' in df_work.columns and 'longitude' in df_work.columns:
            # Simple spatial binning (could use your k-means clusters instead!)
            df_work['lat_bin'] = pd.cut(df_work['latitude'], bins=10, labels=False)
            df_work['lon_bin'] = pd.cut(df_work['longitude'], bins=10, labels=False)
            df_work['spatial_cell'] = df_work['lat_bin'].astype(str) + '_' + df_work['lon_bin'].astype(str)
            
            # Create sequences within each spatial cell
            for cell, cell_df in df_work.groupby('spatial_cell'):
                cell_df = cell_df.sort_values('datetime')
                current_seq = []
                seq_start_time = None
                seq_crimes = []
                
                for idx, row in cell_df.iterrows():
                    crime_type = row.get('crime_type', 'UNKNOWN')
                    crime_time = row['datetime']
                    
                    if seq_start_time is None or (crime_time - seq_start_time) <= timedelta(hours=time_window_hours):
                        current_seq.append(crime_type)
                        seq_crimes.append(idx)
                        if seq_start_time is None:
                            seq_start_time = crime_time
                    else:
                        if len(current_seq) >= 2:
                            sequences.append(current_seq)
                            sequence_metadata.append({
                                'seq_id': len(sequences),
                                'spatial_cell': cell,
                                'length': len(current_seq),
                                'start_time': seq_start_time,
                                'crime_indices': seq_crimes
                            })
                        current_seq = [crime_type]
                        seq_crimes = [idx]
                        seq_start_time = crime_time
                
                if len(current_seq) >= 2:
                    sequences.append(current_seq)
                    sequence_metadata.append({
                        'seq_id': len(sequences),
                        'spatial_cell': cell,
                        'length': len(current_seq),
                        'start_time': seq_start_time,
                        'crime_indices': seq_crimes
                    })
    
    metadata_df = pd.DataFrame(sequence_metadata)
    return sequences, metadata_df


def run_crime_sequence_mining(
    df: pd.DataFrame,
    *,
    min_support: float = 0.01,
    time_window_hours: int = 24,
    area_col: Optional[str] = None,
    grouping_method: str = 'area_based',
    max_patterns: int = 50
) -> Dict:

    # Prepare sequences
    sequences, metadata_df = prepare_crime_sequences(
        df,
        time_window_hours=time_window_hours,
        area_col=area_col,
        grouping_method=grouping_method
    )
    
    if not sequences:
        return {
            'n_sequences': 0,
            'patterns': [],
            'message': 'No sequences found with current parameters'
        }
    
    # running PrefixSpan algo 
    prefixspan = PrefixSpan(min_support=min_support)
    patterns = prefixspan.fit(sequences)
    
    # Format results
    formatted_patterns = []
    for pattern, support in patterns[:max_patterns]:
        formatted_patterns.append({
            'pattern': list(pattern),
            'support_count': int(support),
            'support_pct': round(support / len(sequences) * 100, 2),
            'length': len(pattern)
        })
    
    # stats
    stats = {
        'n_sequences': len(sequences),
        'n_patterns_found': len(patterns),
        'avg_sequence_length': round(np.mean([len(s) for s in sequences]), 2),
        'max_sequence_length': max([len(s) for s in sequences]),
        'min_support_threshold': min_support,
        'time_window_hours': time_window_hours,
        'grouping_method': grouping_method
    }
    
    return {
        'statistics': stats,
        'patterns': formatted_patterns,
        'sequence_metadata': metadata_df.to_dict(orient='records') if not metadata_df.empty else []
    }


if __name__ == "__main__":

    df = pd.read_csv("../crime_data_cleaned.csv").head(100000)
    #df = pd.read_csv("../crime_safety_cleaned.csv")
    #df = pd.concat([df1, df2], ignore_index=True)
    
    print(f"\n Testing with total data: {len(df)} records")
    
    print("\n=== CRIME SEQUENCE PATTERN MINING ===\n")
    
    result = run_crime_sequence_mining(
        df,
        min_support=0.005,
        time_window_hours=48,
        grouping_method='area_based', #temporal_only, area_based, spatial_temporal
        max_patterns=20
    )
    
    print(f"Statistics:")
    for key, value in result['statistics'].items():
        print(f"  {key}: {value}")
    
    print(f"\nTop Frequent Patterns:")
    for i, pattern in enumerate(result['patterns'][:10], 1):
        crimes = ' → '.join(pattern['pattern'])
        print(f"{i:2d}. {crimes}")
        print(f"    Support: {pattern['support_count']} sequences ({pattern['support_pct']}%)")
        print()
