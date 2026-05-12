"""
Compare the average connectivity between the resting state previous to the task and the task

Federico Ramírez-Toraño
04/05/2026
"""

# Imports
import os
import glob
from pathlib import Path

import matplotlib
matplotlib.use("Qt5Agg")

import numpy
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

from nilearn import plotting
from scipy.stats import pearsonr
from scipy.io import loadmat


# ============================================================
# Parameters
# ============================================================

config = {}
config['path'] = {}
config['path']['demographic'] = os.path.join('data','demographic','HIQ_0_demographic_DWI.csv')
config['path']['sc'] = os.path.join('data','sc')
config["path"]["template"] = os.path.join('data','template')
config['path']['figures'] = os.path.join('figures')

connectivity_methods = ["num_streamlines_raw", "median_fa_raw"]

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
        current_method
    )
    output_folder.mkdir(parents=True, exist_ok=True)


    for current_network in networks_of_interest.keys():

        print(f"    Working on network: {current_network}")

        for isub, current_sub in enumerate(sub):

            # ----------------------------
            # Load sc mat file
            # ----------------------------
            current_mat = glob.glob(os.path.join(config['path']['sc'], f"*{current_sub}*.mat"))
            current_mat = loadmat(current_mat[0])

            # ----------------------------
            # Node-level SC
            # ----------------------------

            current_sc = current_mat[current_method]
            nodes_mean = numpy.empty(current_sc.shape[0])
            nodes_mean[:] = numpy.nan

            # Get the index of interest
            idx = [i for i,current_nick in enumerate(nicks) if current_nick in networks_of_interest_nick[current_network]]

            for current_idx in idx:

                current_row = current_sc[current_idx]
                mask = numpy.zeros_like(current_row, dtype=bool)
                mask[idx] = True
                mask[current_idx] = False
                current_row = current_row[mask]
                nodes_mean[current_idx] = numpy.mean(current_row)

                results_node.append({
                    "subject": current_sub,
                    "method": current_method,
                    "network": current_network,
                    "nick": nicks[current_idx],
                    "IG": demographic.loc[isub, "IG"],
                    "mean": nodes_mean[current_idx]
                })

            results_network.append({
                "subject": current_sub,
                "method": current_method,
                "network": current_network,
                "IG": demographic.loc[isub, "IG"],
                "mean": numpy.nanmean(nodes_mean),
            })


    # ========================================================
    # Save results
    # ========================================================

    results_network = pd.DataFrame(results_network)
    results_node = pd.DataFrame(results_node)

    # ========================================================
    # Scatter plots: network mean vs IG
    # ========================================================

    print(f"Plotting scatterplots for {current_method.upper()}...")

    for current_network in networks_of_interest.keys():

        df = results_network[
            (results_network["network"] == current_network)
        ].dropna(subset=["IG", "mean"])

        r, p = pearsonr(df["IG"], df["mean"])
        r2 = r ** 2

        ax = sns.scatterplot(x="IG", y="mean", data=df)
        sns.regplot(
            x="IG",
            y="mean",
            data=df,
            ax=ax,
            scatter=False
        )

        ax.set_title(
            f"{current_method.upper()} -IG correlation - "
            f"{current_network}"
        )
        ax.set_xlabel("IG")
        ax.set_ylabel(f"{current_method.upper()}")

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
            f"{current_network}_scatterplot.png"
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

    for current_network in networks_of_interest_nick.keys():

        coords_net = []
        r_values = []

        for iarea in range(len(networks_of_interest_nick[current_network])):

            current_nick = networks_of_interest_nick[current_network][iarea]

            df = results_node[
                (results_node["network"] == current_network) &
                (results_node["nick"] == current_nick)
            ].dropna(subset=["IG", "mean"])

            r, p = pearsonr(df["IG"], df["mean"])

            idx = [i for i in range(len(nicks)) if current_nick == nicks[i]][0]
            coords_net.append(coordinates[idx])
            r_values.append(r)

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
            f"{current_network} - {current_method} vs IG",
            color="black"
        )

        figure_path = (
            output_folder /
            f"{current_network}_glassbrain.png"
        )

        plt.savefig(
            figure_path,
            dpi=300,
            bbox_inches="tight",
            facecolor="white"
        )
        plt.close()