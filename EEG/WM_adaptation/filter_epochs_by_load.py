import numpy as np
import pandas as pd
import mne
from scipy.io import loadmat


def add_2wm_metadata_to_epochs(epochs, mat_path, raw, event_code=32):

    mat = loadmat(mat_path, squeeze_me=False, struct_as_record=False)
    stim = mat["stim"][0, 0]

    # ---- setSize (60 x 5 → 300 trials)
    set_size = np.asarray(stim.setSize).flatten(order="F").astype(int)

    # ---- triggers
    triggers = stim.triggers[0,0]

    trigger_values = np.asarray(triggers.value).squeeze().astype(int)
    trigger_onsets = np.asarray(triggers.onset).squeeze()

    # ---- seleccionar sólo los triggers 32 del MAT
    mat_s32_idx = np.where(trigger_values == event_code)[0]

    if len(mat_s32_idx) != len(set_size):
        raise ValueError(
            f"Mismatch: {len(set_size)} setSize vs "
            f"{len(mat_s32_idx)} MAT triggers {event_code}"
        )

    # ---- reconstruir eventos EEG completos
    event_id = getattr(raw, "_event_id", None)

    if event_id is not None:
        event_id = {str(k): int(v) for k, v in event_id.items()}
        available = set(map(str, raw.annotations.description))
        event_id = {k: v for k, v in event_id.items() if k in available}

        events_all, _ = mne.events_from_annotations(
            raw,
            event_id=event_id,
            verbose=False
        )
    else:
        events_all, event_id = mne.events_from_annotations(raw, verbose=False)

    eeg_s32_idx = np.where(events_all[:, 2] == event_code)[0]

    # ---- mapear epochs → MAT trials
    mat_trials = []

    for selected_idx in epochs.selection:
        match = np.where(eeg_s32_idx == selected_idx)[0]

        if len(match) != 1:
            raise ValueError(
                f"Could not map epoch index {selected_idx}"
            )

        mat_trials.append(match[0])

    mat_trials = np.asarray(mat_trials)

    # ---- asignar metadata
    epochs.metadata = pd.DataFrame({
        "set_size": set_size[mat_trials],
        "mat_trial": mat_trials
    })

    return epochs