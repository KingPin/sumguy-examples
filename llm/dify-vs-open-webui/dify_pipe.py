import requests
from pydantic import BaseModel, Field


class Pipe:
    class Valves(BaseModel):
        DIFY_URL: str = Field(default="http://nginx/v1")
        DIFY_APP_KEY: str = Field(default="")

    def __init__(self):
        self.valves = self.Valves()

    def pipes(self):
        return [{"id": "dify-support-bot", "name": "Dify: Support Bot"}]

    def pipe(self, body: dict) -> str:
        content = body["messages"][-1]["content"]
        # Messages with images arrive as a list of parts; keep the text ones.
        if isinstance(content, list):
            content = " ".join(p.get("text", "") for p in content if p.get("type") == "text")
        query = content
        r = requests.post(
            f"{self.valves.DIFY_URL}/chat-messages",
            headers={"Authorization": f"Bearer {self.valves.DIFY_APP_KEY}"},
            json={
                "inputs": {},
                "query": query,
                "response_mode": "blocking",
                "user": "open-webui",
            },
            timeout=120,
        )
        r.raise_for_status()
        return r.json()["answer"]
