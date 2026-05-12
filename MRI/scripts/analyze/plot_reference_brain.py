"""
Create reference brain figure with AAL network nodes and nick labels.
"""

# Imports
import os
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt

from scipy.io import loadmat
from nilearn import plotting
from matplotlib.colors import ListedColormap


# ============================================================
# Parameters
# ============================================================

config = {}
config["path"] = {}
config["path"]["template"] = os.path.join("data", "template")
config["path"]["figures"] = os.path.join("figures")

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
# Output folder
# ============================================================

output_folder = Path(config["path"]["figures"]) / "cerebro_referencia"
output_folder.mkdir(parents=True, exist_ok=True)


# ============================================================
# Load AAL template
# ============================================================

matfile = os.path.join(config["path"]["template"], "template_AAL.mat")
mat = loadmat(matfile)

coordinates = mat["atlas"]["pos"][0][0] * 1000
nicks_nested = mat["atlas"]["nick"][0][0]
nicks = [n[0][0] for n in nicks_nested]


# ============================================================
# Create figure
# ============================================================

network_names = list(networks_of_interest_nick.keys())

fig, axes = plt.subplots(
    1,
    len(network_names),
    figsize=(24, 8),
    facecolor="white"
)

if len(network_names) == 1:
    axes = [axes]

red_cmap = ListedColormap(["red"])

for ax, current_network in zip(axes, network_names):

    # Remove duplicated nicks while preserving order
    current_nicks = list(dict.fromkeys(networks_of_interest_nick[current_network]))

    coords_net = []
    labels_net = []

    for current_nick in current_nicks:

        idx = [i for i, nick in enumerate(nicks) if nick == current_nick]

        if len(idx) == 0:
            print(f"Nick not found: {current_nick}")
            continue

        idx = idx[0]

        coords_net.append(coordinates[idx])
        labels_net.append(current_nick)

    coords_net = np.asarray(coords_net)

    if coords_net.shape[0] == 0:
        ax.set_title(current_network)
        ax.axis("off")
        continue

    node_values = np.ones(coords_net.shape[0])
    node_size = np.ones(coords_net.shape[0]) * 80

    display = plotting.plot_markers(
        node_values=node_values,
        node_coords=coords_net,
        node_size=node_size,
        node_cmap=red_cmap,
        node_vmin=0,
        node_vmax=1,
        display_mode="z",
        black_bg=False,
        colorbar=False,
        axes=ax,
        figure=fig,
        title=current_network,
        annotate=False
    )

    # Get Nilearn internal axis for the axial/top view
    nilearn_ax = display.axes["z"].ax

    # Add nick labels
    for coord, label in zip(coords_net, labels_net):
        nilearn_ax.text(
            coord[0] + 3,
            coord[1] + 3,
            label,
            fontsize=7,
            color="black",
            ha="left",
            va="center",
            zorder=100,
            clip_on=False,
            bbox=dict(
                boxstyle="round,pad=0.12",
                facecolor="white",
                edgecolor="none",
                alpha=0.75
            )
        )


# ============================================================
# Save figure
# ============================================================

fig.suptitle(
    "AAL network reference nodes",
    fontsize=18,
    color="black"
)

plt.subplots_adjust(
    left=0.02,
    right=0.98,
    top=0.90,
    bottom=0.02,
    wspace=0.05
)

figure_path = output_folder / "AAL_network_nodes_reference.png"

plt.savefig(
    figure_path,
    dpi=300,
    facecolor="white"
)

plt.close()

print(f"Saved figure: {figure_path}")