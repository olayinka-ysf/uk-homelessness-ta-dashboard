import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import seaborn as sns
from pathlib import Path

PROCESSED = Path("data/processed")
OUT = Path("screenshots")
OUT.mkdir(exist_ok=True)

sns.set_theme(style="whitegrid", font_scale=1.05)
C = ["#1f4e79", "#2e75b6", "#70ad47", "#ffc000", "#c00000"]

ts = pd.read_csv(PROCESSED / "timeseries_clean.csv")
la = pd.read_csv(PROCESSED / "la_detailed_clean.csv")
imd = pd.read_csv(PROCESSED / "imd_clean.csv")

ts["label"] = ts["year"].astype(str) + "-Q" + ts["quarter"].astype(str)

# ── Chart 1: Prevention and relief duties trend ───────────────────────────────
duties = ts[ts["prevention_duties"].notna()].copy()

fig, ax = plt.subplots(figsize=(13, 6))
ax.plot(duties["label"], duties["prevention_duties"] / 1000, label="Prevention duties", color=C[0], linewidth=2)
ax.plot(duties["label"], duties["relief_duties"] / 1000, label="Relief duties", color=C[1], linewidth=2)
ax.set_title("Quarterly Prevention and Relief Duties Accepted in England", fontsize=13, pad=12)
ax.set_xlabel("Quarter")
ax.set_ylabel("Duties accepted (thousands)")
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:.0f}k"))
tick_step = max(1, len(duties) // 12)
ax.set_xticks(range(0, len(duties), tick_step))
ax.set_xticklabels(duties["label"].iloc[::tick_step], rotation=45, ha="right")
ax.legend()
plt.tight_layout()
fig.savefig(OUT / "duties_trend.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("duties_trend.png saved")

# ── Chart 2: TA households over time with children series ─────────────────────
ta_trend = ts[ts["ta_with_children"].notna()].copy()

fig, ax = plt.subplots(figsize=(13, 6))
ax.plot(ta_trend["label"], ta_trend["total_ta_households"] / 1000, label="Total TA households", color=C[0], linewidth=2)
ax.plot(ta_trend["label"], ta_trend["ta_with_children"] / 1000, label="Households with children", color=C[2], linewidth=2, linestyle="--")
ax.fill_between(range(len(ta_trend)), ta_trend["ta_with_children"] / 1000, ta_trend["total_ta_households"] / 1000, alpha=0.08, color=C[0])
ax.set_title("Households in Temporary Accommodation by Quarter", fontsize=13, pad=12)
ax.set_xlabel("Quarter")
ax.set_ylabel("Households (thousands)")
tick_step = max(1, len(ta_trend) // 14)
ax.set_xticks(range(0, len(ta_trend), tick_step))
ax.set_xticklabels(ta_trend["label"].iloc[::tick_step], rotation=45, ha="right")
ax.legend()
plt.tight_layout()
fig.savefig(OUT / "ta_trend.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("ta_trend.png saved")

# ── Chart 3: Top 15 LAs by TA rate per 1,000 households ──────────────────────
la_rate = la[la["households_in_area_000s"] > 0].copy()
la_rate["ta_rate_per_1000"] = la_rate["total_ta_households"] / la_rate["households_in_area_000s"]
top15 = la_rate.nlargest(15, "ta_rate_per_1000").sort_values("ta_rate_per_1000")

fig, ax = plt.subplots(figsize=(11, 8))
bars = ax.barh(top15["local_authority_name"], top15["ta_rate_per_1000"], color=C[0], edgecolor="white")
ax.bar_label(bars, fmt="%.1f", padding=3, fontsize=9)
ax.set_title("Top 15 Local Authorities by TA Rate per 1,000 Households\n(April to June 2025)", fontsize=13, pad=12)
ax.set_xlabel("TA households per 1,000 estimated households")
ax.set_ylabel("")
ax.set_xlim(0, top15["ta_rate_per_1000"].max() * 1.15)
plt.tight_layout()
fig.savefig(OUT / "ta_rate_by_la.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("ta_rate_by_la.png saved")

# ── Chart 4: Stacked bar chart of TA type by quarter (2018 onwards) ───────────
ta_types = ts[ts["bb_accommodation"].notna()].copy()
ta_types["self_contained"] = ta_types["leased"].fillna(0) + ta_types["la_ha_stock"].fillna(0)
labels = ta_types["label"].values
bb = ta_types["bb_accommodation"].values / 1000
np_vals = ta_types["nightly_paid"].fillna(0).values / 1000
sc = ta_types["self_contained"].values / 1000

fig, ax = plt.subplots(figsize=(13, 6))
ax.bar(labels, bb, label="Bed and breakfast", color=C[0])
ax.bar(labels, np_vals, bottom=bb, label="Nightly paid", color=C[1])
ax.bar(labels, sc, bottom=bb + np_vals, label="Self-contained (leased/LA-HA)", color=C[2])
ax.set_title("Temporary Accommodation by Type per Quarter", fontsize=13, pad=12)
ax.set_xlabel("Quarter")
ax.set_ylabel("Households (thousands)")
tick_step = max(1, len(labels) // 12)
ax.set_xticks(range(0, len(labels), tick_step))
ax.set_xticklabels(labels[::tick_step], rotation=45, ha="right")
ax.legend(loc="upper left")
plt.tight_layout()
fig.savefig(OUT / "ta_type_breakdown.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("ta_type_breakdown.png saved")

# ── Chart 5: Scatter plot IMD score vs TA rate ────────────────────────────────
la_rate = la[la["households_in_area_000s"] > 0].copy()
la_rate["ta_rate_per_1000"] = la_rate["total_ta_households"] / la_rate["households_in_area_000s"]
merged = la_rate.merge(imd[["local_authority_code", "imd_score", "imd_decile"]], on="local_authority_code", how="inner")

fig, ax = plt.subplots(figsize=(11, 7))
scatter = ax.scatter(
    merged["imd_score"], merged["ta_rate_per_1000"],
    c=merged["imd_decile"], cmap="RdYlBu_r",
    alpha=0.65, edgecolors="white", linewidths=0.4, s=55
)
cbar = plt.colorbar(scatter, ax=ax)
cbar.set_label("IMD Decile (1 = most deprived)")
ax.set_title("Deprivation Score vs Temporary Accommodation Rate\nby Local Authority", fontsize=13, pad=12)
ax.set_xlabel("IMD Average Score (higher = more deprived)")
ax.set_ylabel("TA households per 1,000 estimated households")
plt.tight_layout()
fig.savefig(OUT / "imd_scatter.png", dpi=150, bbox_inches="tight")
plt.close(fig)
print("imd_scatter.png saved")
