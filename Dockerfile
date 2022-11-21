FROM python:3.8-alpine

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY lorawan-test.py .

ENTRYPOINT ["python3" , "lorawan-test.py", "--debug"]