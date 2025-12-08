import math
import random
from typing import Dict, List, Optional, Tuple
import numpy as np
import pandas as pd

# Parse a few time formats like HHMM or HH:MM into timedelta
def parse_time(val):
    if pd.isna(val):
        return None
    try:
        if isinstance(val, (int, float)):
            hh = int(val) // 100
            mm = int(val) % 100
            return pd.to_timedelta(hh, unit="h") + pd.to_timedelta(mm, unit="m")
        if isinstance(val, str):
            s = val.strip()
            if ":" in s:
                parts = s.split(":")
                hh = int(parts[0])
                mm = int(parts[1]) if len(parts) > 1 else 0
                return pd.to_timedelta(hh, unit="h") + pd.to_timedelta(mm, unit="m")
            if s.isdigit() and len(s) == 4:
                hh, mm = int(s[:2]), int(s[2:])
                return pd.to_timedelta(hh, unit="h") + pd.to_timedelta(mm, unit="m")
        return None
    except Exception:
        return None

# Build feature matrix with lat/lon and time features
def build_time_location_features(
    df: pd.DataFrame,
    *,
    datetime_col: Optional[str] = None,
    time_col: Optional[str] = None,
    lat_col: Optional[str] = None,
    lon_col: Optional[str] = None,
) -> Tuple[np.ndarray, pd.DataFrame]:
    date_col = datetime_col
    time_col_name = time_col
    lat_col_name = lat_col
    lon_col_name = lon_col

    required = [date_col, time_col_name, lat_col_name, lon_col_name]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")

    working = df[[date_col, time_col_name, lat_col_name, lon_col_name]].copy()
    working[date_col] = pd.to_datetime(working[date_col], errors="coerce")
    working["__time_delta"] = working[time_col_name].apply(parse_time)
    working["dt"] = working[date_col] + working["__time_delta"].fillna(pd.Timedelta(0))

    working = working.dropna(subset=["dt", lat_col_name, lon_col_name])
    if working.empty:
        raise ValueError("No rows with valid datetime/lat/lon values")

    hours = working["dt"].dt.hour.fillna(0).astype(float)
    hour_rad = 2 * math.pi * hours / 24.0
    dow = working["dt"].dt.dayofweek.fillna(0).astype(float)
    dow_rad = 2 * math.pi * dow / 7.0

    X = np.vstack(
        [
            working[lat_col_name].astype(float).to_numpy(),
            working[lon_col_name].astype(float).to_numpy(),
            np.sin(hour_rad),
            np.cos(hour_rad),
            np.sin(dow_rad),
            np.cos(dow_rad),
        ]
    ).T

    return X, working.reset_index(drop=False)

# K-Means++ centroid initialization
def kmeans_plus_plus_init(X: np.ndarray, k: int, rng: random.Random) -> np.ndarray:
    n_samples = X.shape[0]
    centroids = []
    first_idx = rng.randrange(n_samples)
    centroids.append(X[first_idx])

    for _ in range(1, k):
        dist_sq = np.min(
            np.square(np.linalg.norm(X[:, None, :] - np.array(centroids)[None, :, :], axis=2)),
            axis=1,
        )
        probs = dist_sq / dist_sq.sum()
        cumulative_probs = np.cumsum(probs)
        r = rng.random()
        next_idx = np.searchsorted(cumulative_probs, r)
        centroids.append(X[next_idx])

    return np.array(centroids)

def kmeans(
    X: np.ndarray,
    k: int,
    *,
    max_iter: int = 100,
    tol: float = 1e-4,
    random_state: Optional[int] = None,
) -> Tuple[np.ndarray, np.ndarray]:
    # K-Means implementation
    if k <= 0:
        raise ValueError("k has to be positive")
    if X.shape[0] < k:
        raise ValueError("Number of samples has to be >= k")

    rng = random.Random(random_state)
    centroids = kmeans_plus_plus_init(X, k, rng)

    for _ in range(max_iter):
        distances = np.linalg.norm(X[:, None, :] - centroids[None, :, :], axis=2)
        labels = np.argmin(distances, axis=1)

        new_centroids = np.array(
            [X[labels == i].mean(axis=0) if np.any(labels == i) else centroids[i] for i in range(k)]
        )

        shift = np.linalg.norm(new_centroids - centroids, axis=1).max()
        centroids = new_centroids
        if shift <= tol:
            break

    return labels, centroids

def run_hotspot_kmeans(
    df: pd.DataFrame,
    *,
    k: int = 5,
    max_iter: int = 100,
    tol: float = 1e-4,
    random_state: Optional[int] = None,
    datetime_col: Optional[str] = None,
    time_col: Optional[str] = None,
    lat_col: Optional[str] = None,
    lon_col: Optional[str] = None,
) -> Dict[str, object]:
    # Build features, run k-means, and return labels and centroids
    X, cleaned_df = build_time_location_features(
        df,
        datetime_col=datetime_col,
        time_col=time_col,
        lat_col=lat_col,
        lon_col=lon_col,
    )

    labels, centroids = kmeans(
        X,
        k,
        max_iter=max_iter,
        tol=tol,
        random_state=random_state,
    )

    cleaned_df = cleaned_df.assign(cluster=labels)

    centroid_dicts: List[Dict[str, float]] = []
    for idx, c in enumerate(centroids):
        centroid_dicts.append(
            {
                "cluster": int(idx),
                "latitude": float(c[0]),
                "longitude": float(c[1]),
                "hour_sin": float(c[2]),
                "hour_cos": float(c[3]),
                "dow_sin": float(c[4]),
                "dow_cos": float(c[5]),
            }
        )

    return {
        "centroids": centroid_dicts,
        "assignments": cleaned_df[["index", "cluster"]].to_dict(orient="records"),
        "counts": cleaned_df["cluster"].value_counts().sort_index().to_dict(),
        "n_rows_used": int(len(cleaned_df)),
    }

# Convert sin/cos back to a value in original period
def decode_cyclical(sin_val: float, cos_val: float, period: float) -> float:
    angle = math.atan2(sin_val, cos_val)
    if angle < 0:
        angle += 2 * math.pi
    return (angle / (2 * math.pi)) * period

def centroid_readable(c: Dict[str, float]) -> str:
    hour = decode_cyclical(c["hour_sin"], c["hour_cos"], 24)
    dow_value = decode_cyclical(c["dow_sin"], c["dow_cos"], 7)
    dow_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    dow_label = dow_names[int(round(dow_value)) % 7]
    return f"hour≈{hour:4.1f} ({dow_label})"

if __name__ == "__main__":
    df = pd.read_csv("crime_data_cleaned.csv")
    result = run_hotspot_kmeans(
        df,
        datetime_col="date",
        time_col="time",
        lat_col="latitude",
        lon_col="longitude",
        k=5,
        random_state=42,
    )
    # Print a summary
    print("Cluster counts:", result["counts"])
    print("Centroids:")
    for c in result["centroids"]:
        readable = centroid_readable(c)
        print(
            f"  #{c['cluster']}: "
            f"lat={c['latitude']:.5f}, lon={c['longitude']:.5f}, "
            f"hour_sin={c['hour_sin']:.3f}, hour_cos={c['hour_cos']:.3f}, "
            f"dow_sin={c['dow_sin']:.3f}, dow_cos={c['dow_cos']:.3f} "
            f"({readable})"
        )
