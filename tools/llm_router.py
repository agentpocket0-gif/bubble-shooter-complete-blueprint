#!/usr/bin/env python3
"""Dept 4: shared NVIDIA RPM pool and per-model Google token-bucket router."""
from __future__ import annotations
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

NVIDIA_BASE = os.environ.get("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1").rstrip("/")
GOOGLE_BASE = os.environ.get("GOOGLE_BASE_URL", "https://generativelanguage.googleapis.com/v1beta").rstrip("/")

NVIDIA_PREFERENCES = {
    "code": [
        "nvidia/nemotron-3.5-lightning-30b",
        "nvidia/nemotron-nano-3-30b-a3b",
        "nvidia/nemotron-3-super-120b-a12b",
        "nvidia/nemotron-3-ultra-550b-a55b",
        "nvidia/nemotron-4-340b-instruct"
    ],
    "vision": ["nvidia/nemotron-3-nano-omni-30b"],
    "quality": ["nvidia/nemotron-4-340b-reward"],
    "safety": ["nvidia/nemotron-3.5-content-safety"],
    "embedding": ["nvidia/nemotron-3-embed-1b"]
}
GEMMA_PREFERENCES = ["gemma-4", "gemma-3"]
GEMINI_PREFERENCES = ["gemini-3.1-flash-lite", "gemini-3.5-flash-lite", "gemini-2.5-flash-lite", "gemini-2.5-flash"]

class TokenBucket:
    def __init__(self, rpm: int):
        self.capacity = float(max(1, rpm))
        self.tokens = self.capacity
        self.rate = self.capacity / 60.0
        self.updated = time.monotonic()
        self.lock = threading.Lock()

    def acquire(self) -> None:
        while True:
            with self.lock:
                now = time.monotonic()
                self.tokens = min(self.capacity, self.tokens + (now - self.updated) * self.rate)
                self.updated = now
                if self.tokens >= 1.0:
                    self.tokens -= 1.0
                    return
                delay = (1.0 - self.tokens) / self.rate
            time.sleep(delay)

def request_json(url: str, headers: dict | None = None, body: dict | None = None, timeout: int = 60) -> dict:
    request_headers = {"Accept": "application/json", "User-Agent": "classic-blast-six-dept-studio/1"}
    if headers:
        request_headers.update(headers)
    payload = None if body is None else json.dumps(body).encode("utf-8")
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=payload, headers=request_headers, method="GET" if payload is None else "POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:1200]
        raise RuntimeError(f"Provider returned HTTP {exc.code}: {detail}") from exc

class LLMRouter:
    def __init__(self):
        self.nvidia_key = os.environ.get("NVIDIA_API_KEY", "").strip()
        self.google_key = os.environ.get("GEMINI_API_KEY", "").strip()
        self._nvidia: list[str] | None = None
        self._google: list[str] | None = None
        self._buckets: dict[str, TokenBucket] = {}

    def discover_nvidia(self) -> list[str]:
        if self._nvidia is not None:
            return self._nvidia
        self._nvidia = []
        if not self.nvidia_key:
            return self._nvidia
        try:
            response = request_json(NVIDIA_BASE + "/models", {"Authorization": "Bearer " + self.nvidia_key})
            self._nvidia = [str(item["id"]) for item in response.get("data", []) if item.get("id")]
        except Exception as exc:
            print("NVIDIA discovery unavailable; checking Google fallback: " + str(exc), file=sys.stderr)
        return self._nvidia

    def discover_google(self) -> list[str]:
        if self._google is not None:
            return self._google
        self._google = []
        if not self.google_key:
            return self._google
        try:
            url = GOOGLE_BASE + "/models?" + urllib.parse.urlencode({"key": self.google_key})
            response = request_json(url)
            self._google = [str(item.get("name", "")).removeprefix("models/") for item in response.get("models", []) if item.get("name")]
        except Exception as exc:
            print("Google discovery unavailable: " + str(exc), file=sys.stderr)
        return self._google

    @staticmethod
    def _resolve(available: list[str], preferences: list[str]) -> str | None:
        for preferred in preferences:
            exact = next((item for item in available if item.lower() == preferred.lower()), None)
            if exact:
                return exact
            partial = next((item for item in available if preferred.lower() in item.lower()), None)
            if partial:
                return partial
        return None

    def resolve(self, purpose: str = "code") -> tuple[str, str, str, int] | None:
        nvidia = self.discover_nvidia()
        preferences = NVIDIA_PREFERENCES.get(purpose, NVIDIA_PREFERENCES["code"])
        selected = self._resolve(nvidia, preferences)
        if selected:
            return ("nvidia", selected, "nvidia:shared", 35)
        if purpose in ("safety", "quality", "embedding"):
            purpose = "code"
        google = self.discover_google()
        if purpose != "vision":
            gemma = self._resolve(google, GEMMA_PREFERENCES)
            if gemma:
                return ("google", gemma, "google:" + gemma, 25)
        gemini = self._resolve(google, GEMINI_PREFERENCES)
        if gemini:
            return ("google", gemini, "google:" + gemini, 10)
        if purpose == "vision":
            any_vision_model = next((name for name in google if "gemini" in name.lower()), None)
            if any_vision_model:
                return ("google", any_vision_model, "google:" + any_vision_model, 10)
        return None

    def complete(self, prompt: str, purpose: str = "code", image_b64: str | None = None) -> str:
        selected = self.resolve(purpose)
        if selected is None:
            raise RuntimeError("No compatible model was discovered. Add GEMINI_API_KEY and/or NVIDIA_API_KEY and check provider access.")
        provider, model, bucket_key, rpm = selected
        self._buckets.setdefault(bucket_key, TokenBucket(rpm)).acquire()
        if provider == "nvidia":
            content: object = prompt
            if image_b64:
                content = [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": "data:image/png;base64," + image_b64}}
                ]
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": content}],
                "temperature": 0.1,
                "max_tokens": 4096,
                "stream": False
            }
            response = request_json(
                NVIDIA_BASE + "/chat/completions",
                {"Authorization": "Bearer " + self.nvidia_key},
                payload,
                timeout=120
            )
            return str(response["choices"][0]["message"]["content"])
        parts = [{"text": prompt}]
        if image_b64:
            parts.append({"inline_data": {"mime_type": "image/png", "data": image_b64}})
        payload = {
            "contents": [{"parts": parts}],
            "generationConfig": {"temperature": 0.1, "maxOutputTokens": 4096}
        }
        url = GOOGLE_BASE + "/models/" + model + ":generateContent?" + urllib.parse.urlencode({"key": self.google_key})
        response = request_json(url, body=payload, timeout=120)
        return str(response["candidates"][0]["content"]["parts"][0]["text"])

if __name__ == "__main__":
    router = LLMRouter()
    models = {
        purpose: (router.resolve(purpose)[1] if router.resolve(purpose) else None)
        for purpose in ("code", "vision", "safety", "quality", "embedding")
    }
    print(json.dumps({
        "nvidia_available_models": len(router.discover_nvidia()),
        "google_available_models": len(router.discover_google()),
        "routes": models
    }, indent=2))
