FROM python:3.11-slim

# Ensure Python doesn't buffer stdout/stderr in Docker containers
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .


# Accept VITE_URL as build arg and set as env
ARG VITE_URL
ENV VITE_URL=${VITE_URL}

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

