import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
PROCESSED = Path("data/processed")
PROCESSED.mkdir(exist_ok=True)

LA_PATTERN = r"^E0[6-9]|^E10"

def _quarterly_rows(df):
    mask = df.iloc[:, 1].astype(str).str.match(r"^Q[1-4]$")
    out = df[mask].copy()
    out.iloc[:, 0] = pd.to_numeric(out.iloc[:, 0], errors="coerce").ffill()
    return out

def _filter_to_q2_2025(df):
    yr = df.iloc[:, 0].astype(int)
    qn = df.iloc[:, 1].astype(str).str[1].astype(int)
    return df[(yr < 2025) | ((yr == 2025) & (qn <= 2))].copy()

def _read_ts_sheet(sheet):
    try:
        return pd.read_excel(RAW / "homelessness_england_timeseries.xlsx", sheet_name=sheet, header=None)
    except Exception:
        return pd.read_excel(RAW / "homelessness_england_timeseries.ods", engine="odf", sheet_name=sheet, header=None)

# ── England time series ──────────────────────────────────────────────────────

def _extract_ts(df, col_map):
    q = _filter_to_q2_2025(_quarterly_rows(df))
    out = pd.DataFrame({"year": q.iloc[:, 0].astype(int).values, "quarter": q.iloc[:, 1].astype(str).str[1].astype(int).values})
    for name, idx in col_map.items():
        out[name] = pd.to_numeric(q.iloc[:, idx], errors="coerce").values
    return out

p1_df = _extract_ts(_read_ts_sheet("P1"), {"prevention_duties": 3})
r1_df = _extract_ts(_read_ts_sheet("R1"), {"relief_duties": 3})
ta1_df = _extract_ts(_read_ts_sheet("TA1"), {
    "total_ta_households": 3, "ta_with_children": 6, "children_in_ta": 7,
    "bb_accommodation": 9, "nightly_paid": 15, "leased": 21,
    "la_ha_stock": 24, "out_of_area": 30,
})

ts = ta1_df.merge(p1_df, on=["year", "quarter"], how="left").merge(r1_df, on=["year", "quarter"], how="left")
ts = ts.sort_values(["year", "quarter"]).reset_index(drop=True)

ts.to_csv(PROCESSED / "timeseries_clean.csv", index=False)
print(f"timeseries_clean.csv: {len(ts)} rows, {ts['year'].min()}-{ts['year'].max()}")

# ── LA detailed file ─────────────────────────────────────────────────────────

# TA1: accommodation breakdown + household count
ta1_la = pd.read_excel(RAW / "homelessness_detailed_la.xlsx", sheet_name="TA1", header=None)
ta1_la = ta1_la[ta1_la.iloc[:, 0].astype(str).str.match(LA_PATTERN)].copy()

ta_df = pd.DataFrame({
    "local_authority_code":        ta1_la.iloc[:, 0].astype(str).values,
    "local_authority_name":        ta1_la.iloc[:, 1].astype(str).values,
    "total_ta_households":         pd.to_numeric(ta1_la.iloc[:, 4], errors="coerce").values,
    "households_in_area_000s":     pd.to_numeric(ta1_la.iloc[:, 5], errors="coerce").values,
    "ta_with_children":            pd.to_numeric(ta1_la.iloc[:, 7], errors="coerce").values,
    "children_in_ta":              pd.to_numeric(ta1_la.iloc[:, 8], errors="coerce").values,
    "bb_accommodation":            pd.to_numeric(ta1_la.iloc[:, 10], errors="coerce").values,
    "bb_with_children":            pd.to_numeric(ta1_la.iloc[:, 11], errors="coerce").values,
    "nightly_paid":                pd.to_numeric(ta1_la.iloc[:, 16], errors="coerce").values,
    "leased":                      pd.to_numeric(ta1_la.iloc[:, 22], errors="coerce").values,
    "la_ha_stock":                 pd.to_numeric(ta1_la.iloc[:, 25], errors="coerce").values,
    "out_of_area_placements":      pd.to_numeric(ta1_la.iloc[:, 31], errors="coerce").values,
})

# A1: prevention and relief duties
a1_la = pd.read_excel(RAW / "homelessness_detailed_la.xlsx", sheet_name="A1", header=None)
a1_la = a1_la[a1_la.iloc[:, 0].astype(str).str.match(LA_PATTERN)].copy()

duties_df = pd.DataFrame({
    "local_authority_code": a1_la.iloc[:, 0].astype(str).values,
    "prevention_duties":    pd.to_numeric(a1_la.iloc[:, 7], errors="coerce").values,
    "relief_duties":        pd.to_numeric(a1_la.iloc[:, 9], errors="coerce").values,
})

# MD1: main duty accepted
md1_la = pd.read_excel(RAW / "homelessness_detailed_la.xlsx", sheet_name="MD1", header=None)
md1_la = md1_la[md1_la.iloc[:, 0].astype(str).str.match(LA_PATTERN)].copy()

main_df = pd.DataFrame({
    "local_authority_code":  md1_la.iloc[:, 0].astype(str).values,
    "main_duty_accepted":    pd.to_numeric(md1_la.iloc[:, 5], errors="coerce").values,
})

la = ta_df.merge(duties_df, on="local_authority_code", how="left")
la = la.merge(main_df, on="local_authority_code", how="left")
la[la.select_dtypes("number").columns] = la.select_dtypes("number").fillna(0)

la.to_csv(PROCESSED / "la_detailed_clean.csv", index=False)
print(f"la_detailed_clean.csv: {len(la)} LAs")

# ── Population estimates ──────────────────────────────────────────────────────

pop_raw = pd.read_excel(RAW / "ons_population_estimates.xlsx", sheet_name="MYE2 - Persons", header=7)
pop_raw = pop_raw[pop_raw["Code"].astype(str).str.match(LA_PATTERN)].copy()

pop = pd.DataFrame({
    "local_authority_code": pop_raw["Code"].astype(str).values,
    "local_authority_name": pop_raw["Name"].astype(str).values,
    "population_2024":      pd.to_numeric(pop_raw["All ages"], errors="coerce").values,
})

pop.to_csv(PROCESSED / "population_clean.csv", index=False)
print(f"population_clean.csv: {len(pop)} LAs")

# ── IMD 2019 ──────────────────────────────────────────────────────────────────

imd_raw = pd.read_excel(RAW / "imd_2019_la_summary.xlsx", sheet_name="IMD", header=0)
imd_raw = imd_raw[imd_raw.iloc[:, 0].astype(str).str.match(LA_PATTERN)].copy()

# Decile from rank of average score (col index 5 = rank; 317 LAs, ceil(rank/31.7))
imd_score_rank = pd.to_numeric(imd_raw.iloc[:, 5], errors="coerce")
imd_decile = ((imd_score_rank - 1) // (imd_raw.shape[0] / 10) + 1).astype(int).clip(1, 10)

imd = pd.DataFrame({
    "local_authority_code": imd_raw.iloc[:, 0].astype(str).values,
    "local_authority_name": imd_raw.iloc[:, 1].astype(str).values,
    "imd_score":            pd.to_numeric(imd_raw.iloc[:, 4], errors="coerce").values,
    "imd_rank":             imd_score_rank.values,
    "imd_decile":           imd_decile.values,
})

imd.to_csv(PROCESSED / "imd_clean.csv", index=False)
print(f"imd_clean.csv: {len(imd)} LAs")
