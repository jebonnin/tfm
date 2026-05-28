import os
import pandas as pd
import numpy as np

folder_path = "cacti_exports"
output_file = "cacti_summary_results.csv"

# -----------------------------
# Funció estadística
# -----------------------------
def stats(series):
    # neteja de dades
    clean = series.replace([np.inf, -np.inf], np.nan).dropna()

    # opcional: eliminar valors absurds (ex: <1 kbps en enllaç 10G)
    clean = clean[clean > 1e3]

    if len(clean) == 0:
        return {
            "mean": np.nan,
            "max": np.nan,
            "min": np.nan,
            "p95": np.nan
        }

    return {
        "mean": float( clean.mean() ),
        "max":  float( clean.max() ),
        "min":  float( clean.min() ),
        "p95":  float( np.percentile(clean, 95) )
    }

# -----------------------------
# Llista de resultats
# -----------------------------
results = []

# -----------------------------
# Processar fitxers
# -----------------------------
for file_name in os.listdir(folder_path):
    if not file_name.endswith(".csv"):
        continue

    file_path = os.path.join(folder_path, file_name)

    rows = []
    data_section = False

    with open(file_path, "r") as f:
        for line in f:
            line = line.strip()

            if line.startswith('"Date"'):
                data_section = True
                continue

            if not data_section:
                continue

            if line == "" or line.count(",") < 2:
                continue

            parts = line.split(",")

            try:
                inbound  = float(parts[1].replace('"', ''))
                outbound = float(parts[2].replace('"', ''))
            except:
                continue

            rows.append([inbound, outbound])

    if len(rows) == 0:
        continue

    df = pd.DataFrame(rows, columns=["Inbound", "Outbound"])

    in_s  = stats(df["Inbound"])
    out_s = stats(df["Outbound"])

    print(f"\nFITXER: {file_name}")
    print("INBOUND:", in_s)
    print("OUTBOUND:", out_s)

    # -----------------------------
    # guardar resultat estructurat
    # -----------------------------
    results.append({
        "file": file_name,

        "in_mean": in_s["mean"],
        "in_max": in_s["max"],
        "in_min": in_s["min"],
        "in_p95": in_s["p95"],

        "out_mean": out_s["mean"],
        "out_max": out_s["max"],
        "out_min": out_s["min"],
        "out_p95": out_s["p95"],
    })

# -----------------------------
# Export a CSV final
# -----------------------------
df_out = pd.DataFrame(results)
df_out.to_csv(output_file, index=False)

print(f"\nRESULTATS GUARDATS A: {output_file}")
