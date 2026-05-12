"""
Estimate ICC of PLV between 1EC and 3EC

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
import pingouin as pg
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
# Helper functions
# ============================================================

def read_connectivity(config, bids, method, space, band_name):
    if method == "plv":
        return read_plv(config, bids, space=space, band_name=band_name)
    elif method == "ciplv":
        return read_ciplv(config, bids, space=space, band_name=band_name)
    else:
        raise ValueError(f"Unknown connectivity method: {method}")


def get_ci95_column(icc_df):
    if "CI95%" in icc_df.columns:
        return "CI95%"
    elif "CI95" in icc_df.columns:
        return "CI95"
    else:
        raise ValueError("No CI95 column found in ICC dataframe.")


def compute_icc_from_wide(
        df,
        group_cols,
        value_1="mean_plv_1EC",
        value_2="mean_plv_3EC"
):
    """
    Compute ICC(C,1) between 1EC and 3EC for each grouping level.
    """

    icc_results = []

    for group_values, df_group in df.groupby(group_cols):

        if not isinstance(group_values, tuple):
            group_values = (group_values,)

        df_long = pd.DataFrame({
            "subject": numpy.concatenate([
                df_group["subject"].values,
                df_group["subject"].values
            ]),
            "session": (
                ["1EC"] * len(df_group) +
                ["3EC"] * len(df_group)
            ),
            "plv": numpy.concatenate([
                df_group[value_1].values,
                df_group[value_2].values
            ])
        })

        df_long = df_long.dropna()

        if df_long["subject"].nunique() < 2:
            continue

        icc = pg.intraclass_corr(
            data=df_long,
            targets="subject",
            raters="session",
            ratings="plv"
        )

        ci_col = get_ci95_column(icc)

        # ICC(C,1): consistency, two-way mixed, single measurement
        icc3 = icc[icc["Type"] == "ICC(C,1)"].iloc[0]

        row = {
            col: val for col, val in zip(group_cols, group_values)
        }

        row.update({
            "ICC_type": "ICC(C,1)",
            "ICC": icc3["ICC"],
            "CI95": icc3[ci_col],
            "F": icc3["F"],
            "df1": icc3["df1"],
            "df2": icc3["df2"],
            "pval": icc3["pval"],
            "n_subjects": df_long["subject"].nunique()
        })

        icc_results.append(row)

    return pd.DataFrame(icc_results)


def get_aal_coordinate(current_nick, nicks, coordinates):
    """
    Get AAL coordinate from template nick.
    Returns NaNs if nick is not found.
    """

    if current_nick not in nicks:
        print(f"WARNING: nick {current_nick} not found in AAL template.")
        return numpy.array([numpy.nan, numpy.nan, numpy.nan])

    nick_index = nicks.index(current_nick)
    return coordinates[nick_index, :]


# ============================================================
# Plot functions
# ============================================================

def plot_scatter_retest_by_band(df, output_folder, level_name="network"):

    for band, df_band in df.groupby("band"):

        networks = list(df_band["network"].drop_duplicates())
        n_networks = len(networks)

        fig, axes = plt.subplots(
            1,
            n_networks,
            figsize=(5 * n_networks, 5),
            sharex=True,
            sharey=True
        )

        if n_networks == 1:
            axes = [axes]

        for ax, network in zip(axes, networks):

            df_plot = df_band[df_band["network"] == network].copy()

            sns.regplot(
                data=df_plot,
                x="mean_plv_1EC",
                y="mean_plv_3EC",
                ax=ax,
                scatter_kws={"s": 45, "alpha": 0.8},
                line_kws={"linewidth": 2}
            )

            min_val = min(
                df_plot["mean_plv_1EC"].min(),
                df_plot["mean_plv_3EC"].min()
            )
            max_val = max(
                df_plot["mean_plv_1EC"].max(),
                df_plot["mean_plv_3EC"].max()
            )

            ax.plot(
                [min_val, max_val],
                [min_val, max_val],
                color="black",
                linestyle="--",
                linewidth=1
            )

            if len(df_plot) > 2:
                r, p = pearsonr(
                    df_plot["mean_plv_1EC"],
                    df_plot["mean_plv_3EC"]
                )
                title = f"{network}\nr = {r:.2f}, p = {p:.3f}"
            else:
                title = f"{network}"

            ax.set_title(title)
            ax.set_xlabel("Mean PLV 1EC")
            ax.set_ylabel("Mean PLV 3EC")

        fig.suptitle(
            f"Scatter 1EC vs 3EC | {level_name} | {band}",
            fontsize=14
        )
        plt.tight_layout()

        plt.savefig(
            output_folder / f"scatter_{level_name}_{band}_all_networks.png",
            dpi=300
        )
        plt.close()


def plot_bland_altman_by_band(df, output_folder, level_name="network"):

    for band, df_band in df.groupby("band"):

        networks = list(df_band["network"].drop_duplicates())
        n_networks = len(networks)

        fig, axes = plt.subplots(
            1,
            n_networks,
            figsize=(5 * n_networks, 5),
            sharey=True
        )

        if n_networks == 1:
            axes = [axes]

        for ax, network in zip(axes, networks):

            df_plot = df_band[df_band["network"] == network].copy()

            mean_values = (
                df_plot["mean_plv_1EC"] +
                df_plot["mean_plv_3EC"]
            ) / 2

            diff_values = (
                df_plot["mean_plv_3EC"] -
                df_plot["mean_plv_1EC"]
            )

            mean_diff = diff_values.mean()
            sd_diff = diff_values.std()

            loa_upper = mean_diff + 1.96 * sd_diff
            loa_lower = mean_diff - 1.96 * sd_diff

            ax.scatter(mean_values, diff_values, alpha=0.8)

            ax.axhline(
                mean_diff,
                color="black",
                linestyle="-",
                linewidth=2,
                label=f"Mean diff = {mean_diff:.3f}"
            )
            ax.axhline(
                loa_upper,
                color="tab:blue",
                linestyle="--",
                linewidth=2,
                label=f"+1.96 SD = {loa_upper:.3f}"
            )
            ax.axhline(
                loa_lower,
                color="tab:blue",
                linestyle=":",
                linewidth=2,
                label=f"-1.96 SD = {loa_lower:.3f}"
            )
            ax.axhline(
                0,
                color="gray",
                linestyle="-.",
                linewidth=1,
                label="Zero diff"
            )

            ax.set_title(f"{network}")
            ax.set_xlabel("Mean PLV across 1EC and 3EC")
            ax.set_ylabel("PLV difference: 3EC - 1EC")

        handles, labels = axes[-1].get_legend_handles_labels()
        fig.legend(
            handles,
            labels,
            loc="lower center",
            ncol=4,
            frameon=False
        )

        fig.suptitle(
            f"Bland–Altman | {band}",
            fontsize=14
        )

        plt.tight_layout(rect=[0, 0.08, 1, 0.95])

        plt.savefig(
            output_folder / f"bland_altman_{level_name}_{band}_all_networks.png",
            dpi=300
        )
        plt.close()


def plot_icc_network_by_band(icc_network, output_folder):

    for band, df_band in icc_network.groupby("band"):

        plt.figure(figsize=(7, 5))

        sns.barplot(
            data=df_band,
            x="network",
            y="ICC",
            errorbar=None
        )

        plt.axhline(
            0.50,
            color="tab:orange",
            linestyle=":",
            linewidth=2,
            label="Moderate (ICC ≥ 0.50)"
        )

        plt.axhline(
            0.75,
            color="tab:green",
            linestyle="--",
            linewidth=2,
            label="Good (ICC ≥ 0.75)"
        )

        plt.axhline(
            0.90,
            color="tab:red",
            linestyle="-.",
            linewidth=2,
            label="Excellent (ICC ≥ 0.90)"
        )

        plt.ylim(0, 1)
        plt.title(f"Network-level ICC between 1EC and 3EC | {band}")
        plt.ylabel("ICC(C,1)")
        plt.xlabel("Network")
        plt.legend(frameon=False)
        plt.tight_layout()

        plt.savefig(
            output_folder / f"icc_network_barplot_{band}.png",
            dpi=300
        )
        plt.close()


def plot_icc_brains_by_band(icc_node, output_folder):

    for band, df_band in icc_node.groupby("band"):

        networks = list(df_band["network"].drop_duplicates())
        n_networks = len(networks)

        fig, axes = plt.subplots(
            1,
            n_networks,
            figsize=(5 * n_networks, 5)
        )

        if n_networks == 1:
            axes = [axes]

        for ax, network in zip(axes, networks):

            df_plot = df_band[df_band["network"] == network].copy()

            df_plot = df_plot.dropna(
                subset=["x", "y", "z", "ICC"]
            )

            coords = df_plot[["x", "y", "z"]].values
            icc_values = df_plot["ICC"].values

            plotting.plot_markers(
                node_values=icc_values,
                node_coords=coords,
                node_size=90,
                node_cmap="Reds",
                node_vmin=0,
                node_vmax=1,
                display_mode="z",
                axes=ax,
                colorbar=True,
                title=network
            )

        fig.suptitle(
            f"Node-level ICC(C,1) | {band}",
            fontsize=14
        )

        plt.tight_layout()

        plt.savefig(
            output_folder / f"icc_brain_nodes_{band}_all_networks.png",
            dpi=300
        )
        plt.close()


# ============================================================
# Parameters
# ============================================================

connectivity_methods = ["plv"]

bands_of_interest = [
    "delta",
    "theta",
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

    print(f"Working on method: {current_method.upper()}")

    results_network = []
    results_node = []

    output_folder = (
        Path(config["path"]["figures"]) /
        "test_retest" /
        current_method
    )
    output_folder.mkdir(parents=True, exist_ok=True)

    for current_band in bands_of_interest:

        print(f"  Working on band: {current_band}")

        for current_network in networks_of_interest.keys():

            print(f"    Working on network: {current_network}")

            for isub, current_sub in enumerate(sub):

                print(
                    f"      Subject {isub + 1}/{len(sub)}: {current_sub}",
                    end="\r"
                )

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

                # ----------------------------
                # Network-level
                # ----------------------------
                mask_network = (
                    source_in_network[iu[0]] &
                    source_in_network[iu[1]] &
                    (src_area[iu[0]] != src_area[iu[1]])
                )

                mean_plv_1EC = numpy.mean(current_conn_1EC[mask_network])
                mean_plv_3EC = numpy.mean(current_conn_3EC[mask_network])

                results_network.append({
                    "subject": current_sub,
                    "method": current_method,
                    "band": current_band,
                    "network": current_network,
                    "mean_plv_1EC": mean_plv_1EC,
                    "mean_plv_3EC": mean_plv_3EC
                })

                # ----------------------------
                # Node-level
                # Seed area vs rest of same network
                # ----------------------------
                for inode, current_index in enumerate(labels_index):

                    current_label = atlas["label"][current_index]

                    current_nick = networks_of_interest_nick[current_network][inode]
                    current_coord = get_aal_coordinate(
                        current_nick,
                        nicks,
                        coordinates
                    )

                    seed = src_area == current_index
                    target = source_in_network & (src_area != current_index)

                    mask_node = (
                        (seed[iu[0]] & target[iu[1]]) |
                        (target[iu[0]] & seed[iu[1]])
                    )

                    mean_plv_1EC = numpy.mean(current_conn_1EC[mask_node])
                    mean_plv_3EC = numpy.mean(current_conn_3EC[mask_node])

                    results_node.append({
                        "subject": current_sub,
                        "method": current_method,
                        "band": current_band,
                        "network": current_network,
                        "label": current_label,
                        "nick": current_nick,
                        "x": current_coord[0],
                        "y": current_coord[1],
                        "z": current_coord[2],
                        "mean_plv_1EC": mean_plv_1EC,
                        "mean_plv_3EC": mean_plv_3EC
                    })

            print("")

    # ========================================================
    # Save PLV results
    # ========================================================

    results_network = pd.DataFrame(results_network)
    results_node = pd.DataFrame(results_node)

    results_network.to_csv(
        output_folder / "plv_network_1EC_3EC.csv",
        sep=";",
        index=False
    )

    results_node.to_csv(
        output_folder / "plv_node_1EC_3EC.csv",
        sep=";",
        index=False
    )

    # ========================================================
    # Compute ICC
    # ========================================================

    icc_network = compute_icc_from_wide(
        results_network,
        group_cols=["method", "band", "network"]
    )

    icc_node = compute_icc_from_wide(
        results_node,
        group_cols=[
            "method",
            "band",
            "network",
            "label",
            "nick",
            "x",
            "y",
            "z"
        ]
    )

    icc_network.to_csv(
        output_folder / "icc_network_1EC_3EC.csv",
        sep=";",
        index=False
    )

    icc_node.to_csv(
        output_folder / "icc_node_1EC_3EC.csv",
        sep=";",
        index=False
    )

    print("Network-level ICC:")
    print(icc_network)

    print("Node-level ICC:")
    print(icc_node)

    # ========================================================
    # Plots
    # ========================================================

    plot_scatter_retest_by_band(
        results_network,
        output_folder,
        level_name="network"
    )

    plot_bland_altman_by_band(
        results_network,
        output_folder,
        level_name="network"
    )

    plot_icc_network_by_band(
        icc_network,
        output_folder
    )

    plot_icc_brains_by_band(
        icc_node,
        output_folder
    )

print("Done.")