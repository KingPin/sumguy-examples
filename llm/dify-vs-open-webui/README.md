# Dify vs Open WebUI: run both, bridged by a Pipe

Files from the SumGuy's Ramblings comparison of Dify and Open WebUI.

- `docker-compose.yml`: Open WebUI pointed at Ollama on the host and at an OpenAI-compatible backend. The `litellm:4000` URL is a placeholder; point it at your own endpoint or delete the line.
- `docker-compose.override.yml`: joins Open WebUI to Dify's `docker_default` network so it can reach Dify's nginx as `http://nginx`.
- `dify_pipe.py`: an Open WebUI Pipe function that shows up as the model "Dify: Support Bot" and forwards the last chat message to a Dify app's `/chat-messages` API.

Write-up: https://sumguy.com/dify-vs-open-webui/

## Prerequisites and tested versions

- Docker with Compose v2
- Open WebUI v0.12.3 (`ghcr.io/open-webui/open-webui:main`)
- Dify 1.17.1, installed from the official repo (`git clone https://github.com/langgenius/dify.git`, then `cd dify/docker`, `cp .env.example .env`, `docker compose up -d`). Its `.env.example` sets no `COMPOSE_PROJECT_NAME`, so the project is named `docker` and the network is `docker_default`.
- A published Dify chat app (Chatflow or Chatbot) and its API key

The compose files were validated with `docker compose config`. `dify_pipe.py` was tested against a stub HTTP server that returns Dify's blocking response shape (`{"answer": ...}`), including a multimodal message. It was not run against a live Dify install.

## Run

```bash
docker network ls | grep docker_default   # Dify must be up first
docker compose up -d
```

Then in Open WebUI: Admin Panel, Functions, add a new function, paste `dify_pipe.py`, save, and fill in the valves:

- `DIFY_URL`: `http://nginx/v1` on the shared network, or `http://<dify-host>/v1`
- `DIFY_APP_KEY`: the app key from the Dify app's API Access page

## Limits

- Sends only the last message and starts a new Dify conversation each turn. Carry `conversation_id` from the response into the next request if you need memory.
- Uses `response_mode: blocking`, so long Dify runs show nothing until they finish. The `timeout` is 120 seconds.
- For a Dify workflow app (not a chat app), call `/workflows/run` instead; the request and response shapes differ.
