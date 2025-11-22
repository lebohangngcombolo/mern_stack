import os
from dotenv import load_dotenv

# Load .env first
load_dotenv()

from app import create_app

# Select config
config_name = os.getenv("FLASK_CONFIG") or "default"
app = create_app(config_name)

if __name__ == "__main__":
    # Run Flask
    app.run(host="0.0.0.0", port=5001, debug=True)
