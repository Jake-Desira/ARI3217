# Start with an image containing Python 3.12 and a minimal Debian system.
FROM python:3.12-slim

# Create /app inside the image if needed.
# Use it as the working folder for the instructions below.
WORKDIR /app

# Copy the dependency list from your Lubuntu project into /app.
COPY requirements.txt .

# Install those dependencies into the image's Python environment.
# --no-cache-dir avoids keeping pip's installation downloads.
# Docker can still cache the completed build step.
RUN pip install --no-cache-dir -r requirements.txt

# Copy the package definition into /app.
COPY pyproject.toml .

# Copy your Python package, configuration and training data into the image.
# Sources are relative to your build context; destinations are under /app.
COPY src ./src
COPY config ./config
COPY data ./data

# Install your own shop_model package, including the shop-train command.
# --no-deps skips dependency installation because we handled it above.
# This is a normal installation, rather than an editable (-e) installation.
RUN pip install --no-cache-dir --no-deps .

# Train the model DURING THE BUILD and save it inside the image.
# Containers created from this image will already have the trained model.
RUN shop-train

# Document that the application listens on port 8888.
# This does not publish the port; docker run needs -p to do that.
EXPOSE 8888

# When a container starts, run the API server.
# shop_model.api:app selects the app object in shop_model/api.py.
# 0.0.0.0 accepts connections through the container's network interfaces.
# The server listens on port 8888.
CMD ["uvicorn", "shop_model.api:app", "--host", "0.0.0.0", "--port", "8888"]