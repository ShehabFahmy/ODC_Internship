FROM python:slim

WORKDIR /metrics

COPY scraper.py .

RUN pip install --no-cache-dir requests psycopg2-binary psutil

CMD ["python", "scraper.py"]
