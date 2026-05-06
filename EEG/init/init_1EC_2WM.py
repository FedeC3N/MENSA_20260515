"""
Prepare the config.json structure

Federico Ramírez-Toraño
28/10/2025
"""

# Imports
import os
import json


def init():

    # Read the config dictionary
    with open('./init/config.json', 'r') as file:
        config = json.load(file)

    # Folders to find the subjects
    config['path'] = {}
    config['path']['data_root'] = os.path.join('data')
    config['path']['features'] = os.path.join(config['path']['data_root'], 'derivatives', 'sEEGnal','feature_extraction')
    config['path']['demographic'] = os.path.join(config['path']['data_root'], 'sourcedata', 'demographic','MENSA_20260515_demográfico.csv')
    config['path']['figures'] = os.path.join('figures')
    config['path']['template'] = os.path.join(config['path']['data_root'], 'sourcedata', 'template')

    return config
