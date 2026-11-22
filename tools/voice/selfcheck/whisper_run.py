# usage: whisper_run.py <manifest.json> <audio dir> <language zh|en> <out.json>
import json, sys, subprocess, os
import numpy as np, torch
from transformers import pipeline
man, adir, lang, out = sys.argv[1:5]
items = json.load(open(man))
done = json.load(open(out)) if os.path.exists(out) else {}
dev = "mps" if torch.backends.mps.is_available() else "cpu"
asr = pipeline("automatic-speech-recognition", model="openai/whisper-large-v3-turbo", device=dev, torch_dtype=torch.float16 if dev == "mps" else torch.float32)
def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()
todo = [it for it in items if it["file"] not in done]
B = 16
for i in range(0, len(todo), B):
    batch = todo[i:i + B]
    xs = [{"raw": load(os.path.join(adir, it["file"] if it["file"].endswith(".mp3") else it["file"] + ".mp3")), "sampling_rate": 16000} for it in batch]
    rs = asr(xs, batch_size=B, generate_kwargs={"language": lang, "task": "transcribe"})
    for it, r in zip(batch, rs): done[it["file"]] = r["text"]
    json.dump(done, open(out, "w"), ensure_ascii=False, indent=0)
    print(len(done), "/", len(items), flush=True)
print("DONE")
