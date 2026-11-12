import logging

logger = logging.getLogger(__name__)


def add_vat(df, rate):
    out = df.copy()
    out["price"] = out["price"] * (1 + rate)
    logger.info("VAT added using rate=%.2f", rate)
    return out