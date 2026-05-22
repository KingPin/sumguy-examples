import requests
r = requests.get("http://localhost:8080/?client=python-requests", timeout=10)
print(f"status={r.status_code} bytes={len(r.content)}")
