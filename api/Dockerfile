FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y libzbar0

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

EXPOSE 8080

COPY . /app

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "8", "app:create_app()"]