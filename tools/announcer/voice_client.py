"""Voice service clients for the announcer pipeline: the real ElevenLabs SDK and a mock that costs nothing.

Both offer the same four calls:
    voice_ids() -> {name: id}
    remaining_credits() -> int | None
    speak(voice_id, text, previous_text=None, next_text=None) -> (mp3 bytes, alignment)
        alignment = {"characters": [...], "character_start_times_seconds": [...], "character_end_times_seconds": [...]}
    transcribe(path) -> text

The real client reads the key from ELEVENLABS_API_KEY, or ELEVENLABS_KEY_ID (the lead's name for it), and never
writes it anywhere. It is only constructed when someone runs generation for real (lead gate: the text is approved
first). An ElevenLabs API key starts with "sk_"; the value shown in the dashboard's key list is only the key *id* and
is rejected by the API, so we say so before sending anything (audio, 2026-09-16).

The mock speaks each word as a short tone burst (silence between words, longer at punctuation) and returns exact
character timings, so slicing, trimming, loudness, encoding, and the mixdown run on real audio. Its "speech to text"
hears as many words as there are bursts in a clip, so a slice that cuts a word in half is caught like a mishearing.
"""

from __future__ import annotations

import base64
import io
import math
import os
import re
import subprocess
import time
import tempfile
import wave
from pathlib import Path

# Either name works; the first one that is set wins.
KEY_ENVS = ("ELEVENLABS_API_KEY", "ELEVENLABS_KEY_ID")
KEY_ENV = KEY_ENVS[1]
KEY_PREFIX = "sk_"
MODEL_ID = "eleven_multilingual_v2"
STT_MODEL_ID = "scribe_v1"
OUTPUT_FORMAT = "mp3_44100_128"
# Credits per character by model (ElevenLabs pricing, checked 2026-09-15: v2 models 1.0, flash/turbo 0.5).
CREDITS_PER_CHARACTER = {"eleven_multilingual_v2": 1.0, "eleven_flash_v2_5": 0.5, "eleven_turbo_v2_5": 0.5}
# The lead's reference used stability 1.0 for an alert voice; commentary wants more life.
VOICE_SETTINGS = {"stability": 0.45, "similarity_boost": 0.8, "style": 0.35, "use_speaker_boost": True}
## How long to wait for one request, and how hard to try again. A generation run costs real money and takes an
## hour and a half; a dropped connection in the middle of it must cost a few seconds, not the run.
REQUEST_TIMEOUT_S = 180.0
RETRY_DELAYS_S = (2.0, 6.0, 15.0, 40.0)
## Errors worth retrying: the network gave up, or the service asked us to slow down. A refusal (a bad key, text the
## service won't say) is not retried, because trying again cannot change the answer.
RETRY_ON = ("timeout", "timed out", "connection", "temporarily", "too many requests", "429",
            "500", "502", "503", "504", "internal server error", "bad gateway", "service unavailable")


## The key from the environment, whichever name it is under ("" when neither is set).
def environment_key() -> str:
    for name in KEY_ENVS:
        value = os.environ.get(name, "").strip()
        if value:
            return value
    return ""


def worth_retrying(error: Exception) -> bool:
    """Whether this failure might succeed on another attempt."""
    text = ("%s %s" % (type(error).__name__, error)).lower()
    status = getattr(error, "status_code", None)
    if status is not None and (status == 429 or 500 <= int(status) < 600):
        return True
    if status is not None:
        return False
    return any(needle in text for needle in RETRY_ON)


def with_retries(call, describe: str, log=None, delays=None):
    """Runs `call`, retrying transient failures with a growing pause. Raises the last error if none of them help.

    `delays` is read at call time, not bound as a default, so a test can shorten it."""
    for attempt, delay in enumerate((RETRY_DELAYS_S if delays is None else delays) + (None,)):
        try:
            return call()
        except Exception as error:
            if delay is None or not worth_retrying(error):
                raise
            if log:
                log("RETRY %s after %s (attempt %d): waiting %.0f s" % (describe, type(error).__name__, attempt + 1, delay))
            time.sleep(delay)


class RealClient:
    def __init__(self, api_key: str | None = None, model_id: str = MODEL_ID):
        key = api_key or environment_key()
        if not key:
            raise RuntimeError("neither %s is set; the key lives in the environment, never in a file"
                               % " nor ".join(KEY_ENVS))
        if not key.startswith(KEY_PREFIX):
            raise RuntimeError(
                "that looks like an ElevenLabs key *id*, not an API key: the API rejects it with "
                "'API key ID used as API key'. Create or rotate a key at elevenlabs.io (Settings -> API Keys); the "
                "%s... value is shown once. Export it as %s before the interactive guard in ~/.bashrc."
                % (KEY_PREFIX, KEY_ENVS[0]))
        from elevenlabs.client import ElevenLabs  # imported here so dry runs and tests don't need the SDK
        from elevenlabs.types import VoiceSettings

        # Generating a long sentence can take a while; the SDK's default read timeout is not sized for it, and a
        # timeout used to abandon the whole run (2026-09-16, at 712 of 2,225 recordings).
        self._client = ElevenLabs(api_key=key, timeout=REQUEST_TIMEOUT_S)
        self._settings = VoiceSettings(**VOICE_SETTINGS)
        self.model_id = model_id

    def voice_ids(self) -> dict:
        found, token = {}, None
        while True:
            page = self._client.voices.search(page_size=100, next_page_token=token)
            for voice in page.voices:
                found[voice.name] = voice.voice_id
            token = getattr(page, "next_page_token", None)
            if not getattr(page, "has_more", False) or not token:
                return found

    def remaining_credits(self):
        subscription = self._client.user.get().subscription
        return subscription.character_limit - subscription.character_count

    def speak(self, voice_id: str, text: str, previous_text: str | None = None, next_text: str | None = None):
        response = self._client.text_to_speech.convert_with_timestamps(
            voice_id=voice_id, text=text, model_id=self.model_id, output_format=OUTPUT_FORMAT,
            voice_settings=self._settings, previous_text=previous_text, next_text=next_text)
        alignment = response.alignment
        return base64.b64decode(response.audio_base_64), {
            "characters": list(alignment.characters),
            "character_start_times_seconds": list(alignment.character_start_times_seconds),
            "character_end_times_seconds": list(alignment.character_end_times_seconds)}

    def transcribe(self, path: Path) -> str:
        with open(path, "rb") as handle:
            return self._client.speech_to_text.convert(model_id=STT_MODEL_ID, file=handle).text


class MockClient:
    SAMPLE_RATE = 22050
    LEAD_IN = 0.2
    TAIL = 0.3
    SECONDS_PER_LETTER = 0.055
    WORD_MIN = 0.12
    WORD_GAP = 0.13
    PUNCTUATION_GAP = 0.3

    def __init__(self, voices: dict | None = None, credits: int = 100000, mishear: set | None = None):
        self._voices = voices if voices is not None else {"JR1": "mock-jr1", "corporate2": "mock-corporate2"}
        self.credits = credits
        self.mishear = mishear or set()
        self.spoken: list[dict] = []

    def voice_ids(self) -> dict:
        return dict(self._voices)

    def remaining_credits(self):
        return self.credits

    def speak(self, voice_id: str, text: str, previous_text: str | None = None, next_text: str | None = None):
        self.spoken.append({"voice_id": voice_id, "text": text, "previous_text": previous_text, "next_text": next_text})
        self.credits -= len(text)
        starts, ends, bursts = [], [], []
        clock = self.LEAD_IN
        for match in re.finditer(r"\S+|\s+", text):
            token = match.group(0)
            if token.isspace():
                gap = self.PUNCTUATION_GAP if re.search(r"[,.!?;]$", text[:match.start()]) else self.WORD_GAP
                for _ in token:
                    starts.append(clock)
                    ends.append(clock + gap / len(token))
                    clock += gap / len(token)
                continue
            letters = max(1, len(re.sub(r"[^A-Za-z']", "", token)))
            length = max(self.WORD_MIN, letters * self.SECONDS_PER_LETTER)
            bursts.append((clock, clock + length))
            for index in range(len(token)):
                starts.append(clock + length * index / len(token))
                ends.append(clock + length * (index + 1) / len(token))
            clock += length
        duration = clock + self.TAIL
        mp3 = _encode_mp3(_tone_wav(bursts, duration, self.SAMPLE_RATE))
        alignment = {"characters": list(text), "character_start_times_seconds": [round(s, 4) for s in starts],
                     "character_end_times_seconds": [round(e, 4) for e in ends]}
        return mp3, alignment

    def transcribe(self, path: Path) -> str:
        """Hears one placeholder word per tone burst; the pipeline compares word counts for mock runs."""
        words = count_bursts(Path(path))
        if Path(path).stem in self.mishear:
            words = max(0, words - 1)
        return " ".join(["word"] * words)


def _tone_wav(bursts: list, duration: float, rate: int) -> bytes:
    frames = bytearray()
    total = int(duration * rate)
    samples = [0] * total
    for number, (start, end) in enumerate(bursts):
        frequency = 180 + 35 * (number % 6)
        first, last = int(start * rate), min(total, int(end * rate))
        span = max(1, last - first)
        for i in range(first, last):
            envelope = min(1.0, (i - first) / (0.01 * rate), (last - i) / (0.01 * rate))
            samples[i] = int(12000 * envelope * math.sin(2 * math.pi * frequency * (i - first) / rate)) if span else 0
    for value in samples:
        frames += int(value).to_bytes(2, "little", signed=True)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(bytes(frames))
    return buffer.getvalue()


def _encode_mp3(wav: bytes) -> bytes:
    result = subprocess.run(["ffmpeg", "-v", "error", "-f", "wav", "-i", "pipe:0", "-c:a", "libmp3lame", "-b:a", "96k",
                             "-ar", "44100", "-f", "mp3", "pipe:1"], input=wav, capture_output=True, check=True)
    return result.stdout


def count_bursts(path: Path) -> int:
    """Stretches of sound separated by silence (the mock's words)."""
    result = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af", "silencedetect=noise=-35dB:d=0.07", "-f", "null", "-"],
                            capture_output=True, text=True)
    log = result.stderr
    starts = [float(x) for x in re.findall(r"silence_start: (-?[\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", log)]
    duration = probe_duration(path)
    # Sound exists between the end of one silence and the start of the next (and at the edges if not silent).
    edges = sorted([(s, "start") for s in starts] + [(e, "end") for e in ends])
    bursts, sounding, cursor = 0, True, 0.0
    for time, kind in edges:
        if kind == "start":
            if sounding and time - cursor > 0.03:
                bursts += 1
            sounding = False
        else:
            sounding, cursor = True, time
    if sounding and duration - cursor > 0.03:
        bursts += 1
    return bursts


def probe_duration(path: Path) -> float:
    result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)],
                            capture_output=True, text=True, check=True)
    return float(result.stdout.strip() or 0.0)


def mock_self_test() -> None:
    """A quick sanity check of the mock (used by the tests)."""
    client = MockClient()
    mp3, alignment = client.speak("mock-jr1", "Green takes it!")
    with tempfile.NamedTemporaryFile(suffix=".mp3") as handle:
        handle.write(mp3)
        handle.flush()
        assert count_bursts(Path(handle.name)) == 3, "three words, three bursts"
    assert len(alignment["characters"]) == len("Green takes it!")
