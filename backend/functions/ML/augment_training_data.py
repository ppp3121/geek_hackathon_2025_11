"""Neutralized: augmentation utilities moved to tools/train/augment_training_data.py

This module was moved to backend/functions/tools/train/ to separate development tools
from runtime code. The minimal placeholder maintains importability without side-effects.
"""

def augment_example(ex, n=3):
    """Placeholder that returns the input unchanged.

    Use backend/functions/tools/train/augment_training_data.py for the full implementation.
    """
    return [ex.get("text", "")] if isinstance(ex, dict) else [ex]
