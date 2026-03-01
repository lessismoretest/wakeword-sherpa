from __future__ import annotations

import os
import subprocess
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

BASE_DIR = Path(__file__).resolve().parent
SCRIPTS_DIR = BASE_DIR / "scripts"

app = FastAPI(title="xiaozhua-mvp-router")

TOKEN = os.getenv("XIAOZHUA_TOKEN", "change-me")
AUTH_ENABLED = os.getenv("XIAOZHUA_AUTH_ENABLED", "0") == "1"
SCRIPT_MAP = {
    "doubao": SCRIPTS_DIR / "call_doubao.sh",
    "gemini": SCRIPTS_DIR / "call_gemini.sh",
    "chatgpt": SCRIPTS_DIR / "call_chatgpt.sh",
    "grok": SCRIPTS_DIR / "call_grok.sh",
}
DEFAULT_TARGET = "gemini"


class RouteRequest(BaseModel):
    target: str | None = None
    query: str


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


def infer_target(query: str) -> str:
    text = query.lower()
    compact = (
        text.replace(" ", "")
        .replace("\t", "")
        .replace("，", "")
        .replace(",", "")
        .replace("。", "")
        .replace(".", "")
    )

    doubao_names = ["豆包", "斗包", "都包", "杜宝", "doubao"]
    call_words = ["打电话", "电话", "通话", "语音", "连线", "呼叫", "语聊", "开聊"]

    if any(k in text for k in ["grok", "xai", "x.ai"]):
        return "grok"
    if any(name in text for name in doubao_names):
        return "doubao"
    if any(name in compact for name in doubao_names) and any(word in compact for word in call_words):
        return "doubao"
    if any(k in text for k in ["chatgpt", "chat gpt", "gpt"]):
        return "chatgpt"
    if any(k in text for k in ["gemini", "双子", "谷歌ai", "google ai"]):
        return "gemini"

    return DEFAULT_TARGET


@app.post("/route")
def route(req: RouteRequest, authorization: str | None = Header(default=None)) -> dict[str, str | bool]:
    if AUTH_ENABLED and authorization != f"Bearer {TOKEN}":
        raise HTTPException(status_code=401, detail="unauthorized")

    target = req.target.lower().strip() if req.target else infer_target(req.query)
    script = SCRIPT_MAP.get(target)
    if script is None:
        raise HTTPException(status_code=400, detail="invalid target")

    if not script.exists():
        raise HTTPException(status_code=500, detail=f"script missing: {script.name}")

    subprocess.Popen([str(script), req.query], cwd=str(BASE_DIR))
    return {"ok": True, "target": target}
