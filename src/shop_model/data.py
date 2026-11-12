import pandas as pd
import logging

logger = logging.getLogger (__name__)

REQUIRED_COLUMNS = {"price", "sold"}


#Load the dataset
def load_data (path):
    df = pd.read_csv(path)
    missing = REQUIRED_COLUMNS - set(df.columns)

    if (missing):
        raise ValueError (f"Missing columns in {path}: {sorted(missing)}")

    logger.info ("Loaded %d rows from %s", len(df), path)

    return (df)

