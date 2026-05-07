"""
Compare the average connectivity between the resting state previous to the task and the following the task

Federico Ramírez-Toraño
04/05/2026
"""

# Imports
import os
from pathlib import Path

import matplotlib
matplotlib.use("Qt5Agg")

import mne
import numpy
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

from nilearn import plotting
from scipy.stats import pearsonr
from scipy.io import loadmat

from init.init_1EC_3EC import init
from sEEGnal.tools.bids_tools import (
    build_BIDS_object,
    read_plv,
    read_ciplv,
    read_forward_model
)
from sEEGnal.tools.template_tools import label_aal


# ============================================================
# Helper function
# ============================================================

def read_connectivity(config, bids, method, space, band_name):
    if method == "plv":
        return read_plv(config, bids, space=space, band_name=band_name)
    elif method == "ciplv":
        return read_ciplv(config, bids, space=space, band_name=band_name)
    else:
        raise ValueError(f"Unknown connectivity method: {method}")


# ============================================================
# Parameters
# ============================================================

connectivity_methods = ["plv", "ciplv"]

bands_of_interest = [
    "delta",
    "theta",
    "alpha",
    "low_beta",
    "high_beta",
    "gamma"
]

networks_of_interest = {
    "DMN": [
        "Frontal_med-lh", "Frontal_med-rh",
        "Frontal_med_orb-lh", "Frontal_med_orb-rh",
        "Frontal_sup_med-lh", "Frontal_sup_med-rh",
        "Frontal_medial_orb-lh", "Frontal_medial_orb-rh",
        "Rectus-lh", "Rectus-rh",
        "Cingulo_post-lh", "Cingulo_post-rh",
        "Precuneus-lh", "Precuneus-rh",
        "Angular-lh", "Angular-rh",
        "Temporal_mid-lh", "Temporal_mid-rh",
        "Temporal_Inf-lh", "Temporal_Inf-rh",
        "Temporal_Pole_mid-lh", "Temporal_Pole_mid-rh",
        "ParaHipocampus-lh", "ParaHipocampus-rh"
    ],

    "SAL": [
        "Insula-lh", "Insula-rh",
        "Cingulo_ant-lh", "Cingulo_ant-rh"
    ],

    "FP": [
        "Frontal_sup-lh", "Frontal_sup-rh",
        "Frontal_sup_orb-lh", "Frontal_sup_orb-rh",
        "Frontal_inf_oper-lh", "Frontal_inf_oper-rh",
        "Frontal_inf_trian-lh", "Frontal_inf_trian-rh",
        "Frontal_inf_orb-lh", "Frontal_inf_orb-rh",
        "Parietal_sup-lh", "Parietal_sup-rh",
        "Parietal_inf-lh", "Parietal_inf-rh",
        "Supramarginal-lh", "Supramarginal-rh",
        "Cingulo_med-lh", "Cingulo_med-rh"
    ]
}

networks_of_interest_nick = {
    "DMN": [
        "lMFG", "rMFG",
        "lMFGo", "rMFGo",
        "lSFGm", "rSFGm",
        "lSFGmo", "rSFGmo",
        "lRectus", "rRectus",
        "lPCC", "rPCC",
        "lPrecu", "rPrecu",
        "lAng", "rAng",
        "lMTG", "rMTG",
        "lITG", "rITG",
        "lTPmid", "rTPmid",
        "lParahip", "rParahip"
    ],

    "SAL": [
        "lInsula", "rInsula",
        "lACC", "rACC"
    ],

    "FP": [
        "lSFG", "rSFG",
        "lSFo", "rSFo",
        "lIFGo", "rIFGo",
        "lIFGt", "rIFGt",
        "lIFGo", "rIFGo",
        "lSPG", "rSPG",
        "lIPG", "rIPG",
        "lSMG", "rSMG",
        "lMCC", "rMCC"
    ]
}


# ============================================================
# Init and load demographics
# ============================================================

config = init()

demographic = pd.read_csv(config["path"]["demographic"], sep=";")

sub = demographic["ID"].values
sub = [current_sub.split("\\")[-1][4:] for current_sub in sub]


# ============================================================
# Load AAL template for glass brain
# ============================================================

matfile = os.path.join(config["path"]["template"], "template_AAL.mat")
mat = loadmat(matfile)

coordinates = mat["atlas"]["pos"][0][0] * 1000
nicks_nested = mat["atlas"]["nick"][0][0]
nicks = [n[0][0] for n in nicks_nested]


# ============================================================
# Main analysis
# ============================================================

for current_method in connectivity_methods:

    print(f"\nWorking on method: {current_method.upper()}")

    results_network = []
    results_node = []

    output_folder = (
        Path(config["path"]["figures"]) /
        "RMSE_1EC_3EC" /
        current_method
    )
    output_folder.mkdir(parents=True, exist_ok=True)

    for current_band in bands_of_interest:

        print(f"  Working on band: {current_band}")

        for current_network in networks_of_interest.keys():

            print(f"    Working on network: {current_network}")

            for isub, current_sub in enumerate(sub):

                # ----------------------------
                # Load 1EC connectivity
                # ----------------------------
                config["subsystem"] = "feature_extraction"
                current_ses = "0"

                BIDS_1EC = build_BIDS_object(
                    config,
                    current_sub,
                    current_ses,
                    "1EC"
                )

                current_conn_1EC, _ = read_connectivity(
                    config,
                    BIDS_1EC,
                    method=current_method,
                    space="source",
                    band_name=current_band
                )

                # ----------------------------
                # Load 3EC connectivity
                # ----------------------------
                BIDS_3EC = build_BIDS_object(
                    config,
                    current_sub,
                    current_ses,
                    "3EC"
                )

                current_conn_3EC, _ = read_connectivity(
                    config,
                    BIDS_3EC,
                    method=current_method,
                    space="source",
                    band_name=current_band
                )

                # ----------------------------
                # Load forward model
                # ----------------------------
                config["subsystem"] = "source_reconstruction"

                forward_model = read_forward_model(config, BIDS_3EC)
                mri_head_t = forward_model["mri_head_t"]
                head_mri_t = mne.transforms.invert_transform(mri_head_t)

                # ----------------------------
                # Label sources with AAL
                # ----------------------------
                atlas = label_aal(
                    config,
                    forward_model["src"],
                    trans=head_mri_t["trans"]
                )

                src_area = atlas["src_area"]

                labels_index = [
                    i for i, label in enumerate(atlas["label"])
                    if label in networks_of_interest[current_network]
                ]

                source_in_network = numpy.isin(src_area, labels_index)

                # ----------------------------
                # Upper triangle source indices
                # ----------------------------
                n = atlas["rr"].shape[0]
                iu = numpy.triu_indices(n, k=1)

                delta = current_conn_1EC - current_conn_3EC

                # ----------------------------
                # Network-level RMSE
                # Excludes within-area source-source connections
                # ----------------------------
                mask_network = (
                    source_in_network[iu[0]] &
                    source_in_network[iu[1]] &
                    (src_area[iu[0]] != src_area[iu[1]])
                )

                rmse_network = numpy.sqrt(
                    numpy.mean(delta[mask_network] ** 2)
                )

                results_network.append({
                    "subject": current_sub,
                    "method": current_method,
                    "band": current_band,
                    "network": current_network,
                    "IG": demographic.loc[isub, "IG"],
                    "RMSE": rmse_network
                })

                # ----------------------------
                # Node-level RMSE
                # Seed area vs rest of same network
                # ----------------------------
                for inode, current_index in enumerate(labels_index):

                    current_label = atlas["label"][current_index]

                    seed = src_area == current_index
                    target = source_in_network & (src_area != current_index)

                    mask_node = (
                        (seed[iu[0]] & target[iu[1]]) |
                        (target[iu[0]] & seed[iu[1]])
                    )

                    rmse_node = numpy.sqrt(
                        numpy.mean(delta[mask_node] ** 2)
                    )

                    results_node.append({
                        "subject": current_sub,
                        "method": current_method,
                        "band": current_band,
                        "network": current_network,
                        "label": current_label,
                        "IG": demographic.loc[isub, "IG"],
                        "RMSE": rmse_node
                    })

    # ========================================================
    # Save results
    # ========================================================

    results_network = pd.DataFrame(results_network)
    results_node = pd.DataFrame(results_node)

    results_network.to_csv(
        output_folder / f"{current_method}_results_network.csv",
        index=False
    )

    results_node.to_csv(
        output_folder / f"{current_method}_results_node.csv",
        index=False
    )

    # ========================================================
    # Scatter plots: network RMSE vs IG
    # ========================================================

    print(f"Plotting scatterplots for {current_method.upper()}...")

    for current_band in bands_of_interest:
        for current_network in networks_of_interest.keys():

            df = results_network[
                (results_network["band"] == current_band) &
                (results_network["network"] == current_network)
            ].dropna(subset=["IG", "RMSE"])

            if len(df) < 3:
                print(
                    f"Skipping scatterplot: {current_method}, "
                    f"{current_band}, {current_network} < 3 subjects"
                )
                continue

            r, p = pearsonr(df["IG"], df["RMSE"])
            r2 = r ** 2

            ax = sns.scatterplot(x="IG", y="RMSE", data=df)
            sns.regplot(
                x="IG",
                y="RMSE",
                data=df,
                ax=ax,
                scatter=False
            )

            ax.set_title(
                f"{current_method.upper()} RMSE-IG correlation - "
                f"{current_band} - {current_network}"
            )
            ax.set_xlabel("IG")
            ax.set_ylabel("RMSE")

            ax.text(
                0.05,
                0.95,
                f"r = {r:.2f}\nR² = {r2:.2f}\np = {p:.3f}",
                transform=ax.transAxes,
                verticalalignment="top",
                bbox=dict(boxstyle="round", alpha=0.2)
            )

            figure_path = (
                output_folder /
                f"{current_band}_{current_network}_scatterplot.png"
            )

            plt.savefig(
                figure_path,
                dpi=300,
                bbox_inches="tight"
            )
            plt.close()

    # ========================================================
    # Glass brain: node-level correlations
    # ========================================================

    print(f"Plotting glass brains for {current_method.upper()}...")

    for current_band in bands_of_interest:
        for current_network in networks_of_interest_nick.keys():

            coords_net = []
            r_values = []

            for iarea in range(len(networks_of_interest_nick[current_network])):

                current_nick = networks_of_interest_nick[current_network][iarea]
                current_label = networks_of_interest[current_network][iarea]

                idx_nick = [
                    i for i, nick in enumerate(nicks)
                    if nick == current_nick
                ]

                if len(idx_nick) == 0:
                    print(f"Nick not found: {current_nick}")
                    continue

                idx_nick = idx_nick[0]

                df = results_node[
                    (results_node["band"] == current_band) &
                    (results_node["network"] == current_network) &
                    (results_node["label"] == current_label)
                ].dropna(subset=["IG", "RMSE"])

                if len(df) < 3:
                    continue

                r, p = pearsonr(df["IG"], df["RMSE"])

                coords_net.append(coordinates[idx_nick])
                r_values.append(r)

            if len(r_values) == 0:
                print(
                    f"Skipping glass brain: {current_method}, "
                    f"{current_band}, {current_network}"
                )
                continue

            coords_net = numpy.array(coords_net)
            r_values = numpy.array(r_values)

            max_abs_r = numpy.max(numpy.abs(r_values))

            if max_abs_r > 0:
                sizes = 30 + 80 * (numpy.abs(r_values) / max_abs_r)
            else:
                sizes = numpy.ones_like(r_values) * 30

            plotting.plot_markers(
                node_values=r_values,
                node_coords=coords_net,
                node_size=sizes,
                node_cmap="coolwarm",
                node_vmin=-0.3,
                node_vmax=0.3,
                display_mode="z",
                black_bg=False,
                colorbar=True
            )

            plt.title(
                f"{current_method.upper()} - {current_network} - {current_band}\n"
                f"Correlation RMSE vs IG",
                color="black"
            )

            figure_path = (
                output_folder /
                f"{current_band}_{current_network}_glassbrain.png"
            )

            plt.savefig(
                figure_path,
                dpi=300,
                bbox_inches="tight",
                facecolor="white"
            )
            plt.close()