from pathlib import Path
import re
import pandas as pd
import os


# =========================
# CONFIG
# =========================

input_dir = Path(os.path.join('data','freesurfer'))
output_csv = Path(os.path.join('data','anat','FreeSurfer_AAL_cortical_measures.csv'))

atlas = "AAL"

regions_of_interest = [
    "Precentral_gyrus", "Frontal_sup", "Frontal_sup_orb", "Frontal_med",
    "Frontal_med_orb", "Frontal_inf_oper", "Frontal_inf_trian",
    "Frontal_inf_orb", "Rolandic_operc", "Supp_Motor", "Olfatory",
    "Frontal_sup_med", "Frontal_medial_orb", "Rectus", "Insula",
    "Cingulo_ant", "Cingulo_med", "Cingulo_post", "ParaHipocampus",
    "Calcarine", "Cuneus", "Lingual", "Occipital_Supp", "Occipital_Mid",
    "Occipital_Inf", "Fusiform", "Postcentral", "Parietal_sup",
    "Parietal_inf", "Supramarginal", "Angular", "Precuneus",
    "Paracentral", "Heschl", "Temporal_Sup", "Temporal_Pole_Sup",
    "Temporal_mid", "Temporal_Pole_mid", "Temporal_Inf"
]

aal_to_nick = {
    "Precentral_gyrus": {"lh": "lPreCG", "rh": "rPreCG"},
    "Frontal_sup": {"lh": "lSFG", "rh": "rSFG"},
    "Frontal_sup_orb": {"lh": "lSFo", "rh": "rSFo"},
    "Frontal_med": {"lh": "lMFG", "rh": "rMFG"},
    "Frontal_med_orb": {"lh": "lMFGo", "rh": "rMFGo"},
    "Frontal_inf_oper": {"lh": "lIFGo", "rh": "rIFGor"},
    "Frontal_inf_trian": {"lh": "lIFGt", "rh": "rIFGt"},
    "Frontal_inf_orb": {"lh": "lIFGo", "rh": "rIFGo"},
    "Rolandic_operc": {"lh": "lRO", "rh": "rRO"},
    "Supp_Motor": {"lh": "lMotor", "rh": "rMotor"},
    "Olfatory": {"lh": "lOlfC", "rh": "rOlfC"},
    "Frontal_sup_med": {"lh": "lSFGm", "rh": "rSFGm"},
    "Frontal_medial_orb": {"lh": "lSFGmo", "rh": "rSFGmo"},
    "Rectus": {"lh": "lRectus", "rh": "rRectus"},
    "Insula": {"lh": "lInsula", "rh": "rInsula"},
    "Cingulo_ant": {"lh": "lACC", "rh": "rACC"},
    "Cingulo_med": {"lh": "lMCC", "rh": "rMCC"},
    "Cingulo_post": {"lh": "lPCC", "rh": "rPCC"},
    "ParaHipocampus": {"lh": "lParahip", "rh": "rParahip"},
    "Calcarine": {"lh": "lCalc", "rh": "rCalc"},
    "Cuneus": {"lh": "lCu", "rh": "rCu"},
    "Lingual": {"lh": "lLingual", "rh": "rLingual"},
    "Occipital_Supp": {"lh": "lSOccL", "rh": "rSOccL"},
    "Occipital_Mid": {"lh": "lMOccL", "rh": "rMOccL"},
    "Occipital_Inf": {"lh": "lIOccL", "rh": "rIOccl"},
    "Fusiform": {"lh": "lFusiG", "rh": "rFusiG"},
    "Postcentral": {"lh": "lPreG", "rh": "rPreG"},
    "Parietal_sup": {"lh": "lSPG", "rh": "rSPG"},
    "Parietal_inf": {"lh": "lIPG", "rh": "rIPG"},
    "Supramarginal": {"lh": "lSMG", "rh": "rSMG"},
    "Angular": {"lh": "lAng", "rh": "rAng"},
    "Precuneus": {"lh": "lPrecu", "rh": "rPrecu"},
    "Paracentral": {"lh": "lParaL", "rh": "rParaL"},
    "Heschl": {"lh": "lHeschl", "rh": "rHeschl"},
    "Temporal_Sup": {"lh": "lSTG", "rh": "rSTG"},
    "Temporal_Pole_Sup": {"lh": "lTPsup", "rh": "rTPsup"},
    "Temporal_mid": {"lh": "lMTG", "rh": "rMTG"},
    "Temporal_Pole_mid": {"lh": "lTPmid", "rh": "rTPmid"},
    "Temporal_Inf": {"lh": "lITG", "rh": "rITG"},
}

columns = [
    "StructName", "NumVert", "SurfArea", "GrayVol", "ThickAvg",
    "ThickStd", "MeanCurv", "GausCurv", "FoldInd", "CurvInd"
]


# =========================
# FUNCTIONS
# =========================

def get_subject_and_hemi_from_filename(txt_file):
    """
    Expected:
    HIQ_024_AAL_lh_FreeSurfer_measures.txt
    HIQ_024_AAL_rh_FreeSurfer_measures.txt
    """
    pattern = re.compile(rf"(.+?)_{atlas}_(lh|rh)_FreeSurfer_measures\.txt$")
    match = pattern.match(txt_file.name)

    if match:
        return match.group(1), match.group(2)

    return None, None


def read_freesurfer_stats(txt_file):
    subject, hemi_from_name = get_subject_and_hemi_from_filename(txt_file)

    # fallback por si acaso
    hemi = hemi_from_name

    df = pd.read_csv(
        txt_file,
        comment="#",
        sep=r"\s+",
        names=columns,
        engine="python"
    )

    df = df[df["StructName"].isin(regions_of_interest)].copy()

    # =========================
    # ADD METADATA
    # =========================

    df.insert(0, "source_file", txt_file.name)
    df.insert(1, "subject", subject)
    df.insert(2, "hemisphere", hemi)

    df["ROI"] = df["StructName"] + "-" + df["hemisphere"]

    df["ROI_nick"] = df.apply(
        lambda row: aal_to_nick[row["StructName"]][row["hemisphere"]],
        axis=1
    )

    return df


# =========================
# RUN
# =========================

all_dfs = []

for txt_file in sorted(input_dir.glob(f"*_{atlas}_*_FreeSurfer_measures.txt")):
    # evita coger subcortical si está en la misma carpeta
    if "subcortical" in txt_file.name:
        continue

    df = read_freesurfer_stats(txt_file)
    all_dfs.append(df)

final_df = pd.concat(all_dfs, ignore_index=True)

output_csv.parent.mkdir(parents=True, exist_ok=True)
final_df.to_csv(output_csv, index=False)

print(f"Saved: {output_csv}")
print(final_df.head())