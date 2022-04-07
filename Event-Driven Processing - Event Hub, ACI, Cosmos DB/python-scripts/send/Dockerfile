FROM python:3.8-alpine
RUN mkdir /app
ADD . /app
WORKDIR /app
RUN apk add --update python3 py-pip python3-dev cmake gcc g++ openssl-dev build-base musl-dev libffi-dev openssl-dev cargo
RUN pip install -r requirements.txt
CMD ["python", "send.py"]