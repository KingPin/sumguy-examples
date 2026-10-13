# Windmill Python version of the same script. Type hints become form fields.
def main(host: str, used_percent: int, threshold: int = 85):
    alert = used_percent >= threshold
    return {"host": host, "used_percent": used_percent, "alert": alert}
