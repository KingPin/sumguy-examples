from flask import Flask
app = Flask(__name__)
@app.get("/")
def hi():
    return "hello\n"
