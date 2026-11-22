# usage: synth.py <jobs.json [{id,text}]> <out dir>   — 用和正式配音一样的声音、语速合成（只做核对用，不进工程）
import asyncio, json, os, sys, subprocess
import edge_tts
jobs = json.load(open(sys.argv[1])); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
async def one(j, sem):
    mp3 = os.path.join(out, j["id"] + ".mp3"); wav = mp3[:-4] + ".wav"
    if os.path.exists(wav): return
    async with sem:
        for attempt in range(4):
            try:
                await edge_tts.Communicate(j["text"], "zh-CN-XiaoxiaoNeural", rate="-8%").save(mp3); break
            except Exception as e:
                if attempt == 3: print("FAIL", j["id"], e); return
                await asyncio.sleep(2 + 3 * attempt)
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", mp3, "-ac", "1", "-ar", "16000", wav])
async def main():
    sem = asyncio.Semaphore(4)
    await asyncio.gather(*[one(j, sem) for j in jobs])
    print("synth done", len(jobs))
asyncio.run(main())
