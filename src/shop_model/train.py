import os
import sys
import logging
from dotenv import load_dotenv

from shop_model.config import load_config
from shop_model.data import load_data
from shop_model.features import add_vat
from shop_model.model import train_model, save_model
from shop_model.logging_setup import setup_logging

from shop_model.seed import set_seed


logger = logging.getLogger (__name__)


#main function
def main ():
    load_dotenv()
    config = load_config()
    set_seed(config["seed"])
    setup_logging(os.environ.get("LOG_LEVEL", "INFO"))

    try:
        DATA_PATH = os.environ.get ("DATA_PATH", config["data_path"])
        MODEL_PATH = os.environ.get ("MODEL_PATH", config["model_path"])


        df1 = load_data (DATA_PATH)
        logger.info ("Data read from %s", DATA_PATH)

        df2 = add_vat (df1, config["vat_rate"])
        logger.info ("VAT rate of %.2f added", config["vat_rate"])

        model = train_model (df2, seed=config["seed"])
        logger.info ("Model trained using seed %d", config["seed"])

        save_model (model, MODEL_PATH)
        logger.info ("Model saved in %s", MODEL_PATH)
    except Exception:
        logger.exception ("Training failed")
        sys.exit (1)


if __name__ == "__main__":
    main ()
