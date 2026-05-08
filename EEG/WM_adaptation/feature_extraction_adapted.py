# -*- coding: utf-8 -*-
"""

This module estimates different measures as requested in config

Federico Ramírez-Toraño
24/02/2026

"""

# Imports
import sys
import pkgutil
import importlib
import traceback
from datetime import datetime as dt, timezone

import WM_adaptation.feature_extraction_adapted


def _load_feature_function(current_feature):
    """
    Load the adapted feature estimation function from WM_adaptation.
    """

    module_path = f"WM_adaptation.estimate_{current_feature}_adapted"
    func_name = f"estimate_{current_feature}"

    try:
        module = importlib.import_module(module_path)
    except ModuleNotFoundError as e:
        raise ImportError(
            f"Could not find module '{module_path}' for feature '{current_feature}'."
        ) from e

    if not hasattr(module, func_name):
        raise ImportError(
            f"Module '{module_path}' does not contain function '{func_name}'."
        )

    return getattr(module, func_name)


def feature_extraction(config, BIDS):
    """

    Call one by one the needed functions for feature extraction

    :arg
    config (dict): Configuration parameters (paths, parameters, etc)
    BIDS (BIDSpath): Metadata to process

    :returns
    A dict with the result of the process

    """

    # Add the subsystem flag
    config['subsystem'] = 'feature_extraction'

    # For each measure, try to estimate the feature
    results = []
    for current_feature in config['feature_extraction']:
        try:

            # Load correct function dynamically
            to_estimate = _load_feature_function(current_feature)

            # Estimate the inverse solution using the defined method
            metadata = to_estimate(config, BIDS)

            # Save the results
            now = dt.now(timezone.utc)
            formatted_now = now.strftime("%d-%m-%Y %H:%M:%S")
            current_results = {
                'result': 'ok',
                'bids_basename': BIDS.basename,
                "date": formatted_now,
                'feature': current_feature,
                'metadata': metadata
            }
            results.append(current_results)

        except Exception as e:

            # Save the error
            now = dt.now(timezone.utc)
            formatted_now = now.strftime("%d-%m-%Y %H:%M:%S")
            current_results = {
                'result': 'error',
                'bids_basename': BIDS.basename,
                "date": formatted_now,
                'feature': current_feature,
                "details": f"Exception: {str(e)}, {traceback.format_exc()}"
            }
            results.append(current_results)


    return results