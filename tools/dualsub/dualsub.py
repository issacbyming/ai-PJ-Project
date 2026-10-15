#!/usr/bin/env python3
"""dualsub: 把 YouTube 影片（或本機影片）做成「中文 + 英文」雙語字幕。

流程:
  1. yt-dlp 下載影片與 YouTube 的英文字幕（官方或自動產生）
  2. 沒有英文字幕時，用 faster-whisper 本機轉錄（選用）
  3. 整段送給 Claude 翻譯成中文（保留上下文，而不是逐句翻）
  4. 輸出與影片同名的 .srt 或 .ass，播放器會自動載入

用法:
  python dualsub.py "https://www.youtube.com/watch?v=XXXX"
  python dualsub.py ./local-video.mp4 --whisper
  python dualsub.py "URL" --format ass --embed
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_MODEL = "claude-opus-5-5"
FALLBACK_MODELS = ("claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-1")
CHUNK_SIZE = 50          # 每次送給 Claude 翻譯的字幕句數
CONTEXT_LINES = 6        # 每個 chunk 附帶前文句數，讓翻譯接得上
VIDEO_EXTS = {".mp4", ".mkv", ".webm", ".mov", ".m4v", ".avi"}


@dataclass
class Cue:
    start: float  # 秒
    end: float
    text: str


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------

def log(msg: str) -> None:
    print(f"[dualsub] {msg}", file=sys.stderr, flush=True)


def load_dotenv(path: Path) -> None:
    """極簡 .env 讀取（只處理 KEY=VALUE，不覆蓋已存在的環境變數）。"""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip().strip("'\"")
        os.environ.setdefault(key, value)


def clean_text(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)          # 去掉 <c> <i> 等標籤
    text = text.replace("&amp;", "&").replace("&gt;", ">").replace("&lt;", "<").replace("&nbsp;", " ")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def fmt_srt_time(sec: float) -> str:
    ms = int(round(sec * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def fmt_ass_time(sec: float) -> str:
    cs = int(round(sec * 100))
    h, cs = divmod(cs, 360_000)
    m, cs = divmod(cs, 6_000)
    s, cs = divmod(cs, 100)
    return f"{h:d}:{m:02d}:{s:02d}.{cs:02d}"


def parse_timestamp(ts: str) -> float:
    ts = ts.strip().replace(",", ".")
    parts = ts.split(":")
    if len(parts) == 2:
        parts.insert(0, "0")
    h, m, s = parts
    return int(h) * 3600 + int(m) * 60 + float(s)


# ---------------------------------------------------------------------------
# 字幕解析
# ---------------------------------------------------------------------------

def parse_json3(path: Path) -> list[Cue]:
    """YouTube 的 json3 格式。自動字幕用這個格式最乾淨，不會有重疊的滾動行。"""
    data = json.loads(path.read_text(encoding="utf-8"))
    cues: list[Cue] = []
    for ev in data.get("events", []):
        if ev.get("aAppend") or "segs" not in ev:
            continue
        text = clean_text("".join(seg.get("utf8", "") for seg in ev["segs"]))
        if not text:
            continue
        start = ev.get("tStartMs", 0) / 1000
        end = start + ev.get("dDurationMs", 0) / 1000
        cues.append(Cue(start, end, text))
    return cues


def parse_vtt_or_srt(path: Path) -> list[Cue]:
    """VTT / SRT。附帶處理 YouTube 自動字幕「每句都重複上一句」的滾動行問題。"""
    raw = path.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n")
    time_re = re.compile(
        r"(\d{1,2}:\d{2}:\d{2}[.,]\d{3}|\d{1,2}:\d{2}[.,]\d{3})\s*-->\s*"
        r"(\d{1,2}:\d{2}:\d{2}[.,]\d{3}|\d{1,2}:\d{2}[.,]\d{3})"
    )
    # 逐行掃描而不是用空行切段：YouTube 自動字幕的時間軸下面常有一行只含空白
    raw_cues: list[tuple[float, float, list[str]]] = []
    current: tuple[float, float, list[str]] | None = None
    for line in raw.split("\n"):
        m = time_re.search(line)
        if m:
            current = (parse_timestamp(m.group(1)), parse_timestamp(m.group(2)), [])
            raw_cues.append(current)
            continue
        if current is None:
            continue  # 檔頭（WEBVTT、Kind、序號等）
        text = clean_text(line)
        if text and not text.isdigit():
            current[2].append(text)

    # 去除滾動重複：若這一塊的第一行等於上一塊的最後一行，去掉它
    result: list[Cue] = []
    prev_last = ""
    for start, end, lines in raw_cues:
        if lines and lines[0] == prev_last:
            lines = lines[1:]
        if not lines:
            continue
        prev_last = lines[-1]
        text = clean_text(" ".join(lines))
        if result and result[-1].text == text:
            result[-1].end = max(result[-1].end, end)
            continue
        result.append(Cue(start, end, text))
    return result


def tidy(cues: list[Cue]) -> list[Cue]:
    """排序、修掉彼此重疊的時間、丟掉空句。"""
    cues = sorted((c for c in cues if c.text), key=lambda c: c.start)
    for i in range(len(cues) - 1):
        if cues[i].end > cues[i + 1].start:
            cues[i].end = max(cues[i].start + 0.3, cues[i + 1].start - 0.01)
    return cues


def load_subtitle_file(path: Path) -> list[Cue]:
    if path.suffix == ".json3" or path.name.endswith(".json3"):
        return tidy(parse_json3(path))
    return tidy(parse_vtt_or_srt(path))


# ---------------------------------------------------------------------------
# 取得影片與英文字幕
# ---------------------------------------------------------------------------

def is_url(s: str) -> bool:
    return re.match(r"^https?://", s) is not None


def find_sidecar_subtitle(video: Path) -> Path | None:
    base = video.with_suffix("")
    for name in [f"{base}.en.json3", f"{base}.en.vtt", f"{base}.en.srt", f"{base}.vtt", f"{base}.srt"]:
        p = Path(name)
        if p.exists():
            return p
    for p in video.parent.glob(f"{video.stem}.en*"):
        if p.suffix in {".json3", ".vtt", ".srt"}:
            return p
    return None


def download(url: str, outdir: Path, max_height: int) -> tuple[Path, Path | None, str]:
    import yt_dlp  # 延後載入，讓本機檔案模式不需要它

    outdir.mkdir(parents=True, exist_ok=True)
    opts = {
        "outtmpl": str(outdir / "%(title)s [%(id)s].%(ext)s"),
        "format": f"bv*[height<={max_height}][ext=mp4]+ba[ext=m4a]/b[height<={max_height}][ext=mp4]/b",
        "merge_output_format": "mp4",
        "writesubtitles": True,
        "writeautomaticsub": True,
        "subtitleslangs": ["en", "en-US", "en-GB", "en-orig"],
        "subtitlesformat": "json3/vtt/srt/best",
        "restrictfilenames": False,
        "windowsfilenames": True,
        "noplaylist": True,
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)
        video_path = Path(ydl.prepare_filename(info)).with_suffix(".mp4")
        if not video_path.exists():
            candidates = [p for p in outdir.iterdir() if f"[{info['id']}]" in p.name and p.suffix in VIDEO_EXTS]
            if not candidates:
                raise RuntimeError("yt-dlp 跑完了但找不到影片檔")
            video_path = candidates[0]

    sub_path: Path | None = None
    for lang, meta in (info.get("requested_subtitles") or {}).items():
        fp = meta.get("filepath")
        if fp and Path(fp).exists():
            sub_path = Path(fp)
            log(f"使用 YouTube 英文字幕 ({lang}): {sub_path.name}")
            break
    if sub_path is None:
        sub_path = find_sidecar_subtitle(video_path)
    return video_path, sub_path, info.get("title", video_path.stem)


def transcribe_with_whisper(video: Path, model_size: str) -> list[Cue]:
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        sys.exit("沒有英文字幕，需要 faster-whisper 才能轉錄：pip install faster-whisper")
    log(f"用 faster-whisper ({model_size}) 轉錄英文，影片越長越久，請稍等…")
    model = WhisperModel(model_size, device="auto", compute_type="auto")
    segments, _info = model.transcribe(str(video), language="en", vad_filter=True, beam_size=5)
    cues = [Cue(s.start, s.end, clean_text(s.text)) for s in segments]
    return tidy(cues)


# ---------------------------------------------------------------------------
# Claude 翻譯
# ---------------------------------------------------------------------------

LANG_NAMES = {"zh-TW": "繁體中文（台灣用語）", "zh-CN": "简体中文"}

SYSTEM_PROMPT = """你是專業的影片字幕譯者，負責把英文字幕翻成{lang}。

規則：
- 每一句英文對應一句中文，編號必須一一對應，不可合併、拆分或跳過。
- 這是口語字幕，翻得自然、簡潔，像母語者在說話，不要翻譯腔。
- 專有名詞、產品名、人名、程式碼、縮寫（API、GPU 等）保留原文。
- 參考前文確保用語一致，但「前文」只是參考，不要翻譯它。
- 不要加註解、不要解釋，只輸出 JSON。

輸出格式（嚴格 JSON，不要加 markdown 圍欄）：
{{"lines": [{{"n": 1, "zh": "..."}}, {{"n": 2, "zh": "..."}}]}}"""


def extract_json(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("回應裡找不到 JSON")
    return json.loads(text[start:end + 1])


class Translator:
    def __init__(self, model: str, lang: str, title: str):
        import anthropic

        self.client = anthropic.Anthropic()
        self.model = model
        self.lang = lang
        self.title = title
        self.system = SYSTEM_PROMPT.format(lang=LANG_NAMES.get(lang, lang))

    def _call(self, prompt: str) -> str:
        kwargs = dict(
            model=self.model,
            max_tokens=16000,
            system=self.system,
            messages=[{"role": "user", "content": prompt}],
        )
        if self.model in FALLBACK_MODELS:
            # 安全分類器誤判時自動改用備援模型，免得整個 chunk 翻譯失敗
            resp = self.client.beta.messages.create(
                betas=["server-side-fallback-2026-07-01"], fallbacks="default", **kwargs
            )
        else:
            resp = self.client.messages.create(**kwargs)
        if resp.stop_reason == "refusal":
            raise RuntimeError("模型拒絕翻譯這段內容")
        return "".join(b.text for b in resp.content if b.type == "text")

    def translate_chunk(self, chunk: list[Cue], context: list[Cue], chunk_no: int) -> list[str]:
        ctx = "\n".join(f"  {c.text}" for c in context) or "  （無）"
        numbered = "\n".join(f"{i + 1}. {c.text}" for i, c in enumerate(chunk))
        prompt = (
            f"影片標題：{self.title}\n\n"
            f"前文（僅供參考，不要翻譯）：\n{ctx}\n\n"
            f"請翻譯以下 {len(chunk)} 句：\n{numbered}"
        )
        last_err: Exception | None = None
        for attempt in range(3):
            try:
                data = extract_json(self._call(prompt))
                mapping = {int(item["n"]): str(item["zh"]).strip() for item in data["lines"]}
                missing = [i + 1 for i in range(len(chunk)) if i + 1 not in mapping]
                if missing:
                    raise ValueError(f"缺少第 {missing[:5]} 句的翻譯")
                return [mapping[i + 1] for i in range(len(chunk))]
            except Exception as e:  # noqa: BLE001
                last_err = e
                log(f"chunk {chunk_no} 第 {attempt + 1} 次失敗：{e}")
        raise RuntimeError(f"chunk {chunk_no} 翻譯失敗：{last_err}")

    def translate_all(self, cues: list[Cue], workers: int) -> list[str]:
        chunks = [cues[i:i + CHUNK_SIZE] for i in range(0, len(cues), CHUNK_SIZE)]
        log(f"共 {len(cues)} 句，分 {len(chunks)} 批送 {self.model} 翻譯…")

        def run(idx: int) -> list[str]:
            start = idx * CHUNK_SIZE
            context = cues[max(0, start - CONTEXT_LINES):start]
            out = self.translate_chunk(chunks[idx], context, idx + 1)
            log(f"  批次 {idx + 1}/{len(chunks)} 完成")
            return out

        with ThreadPoolExecutor(max_workers=workers) as pool:
            results = list(pool.map(run, range(len(chunks))))
        return [zh for part in results for zh in part]


# ---------------------------------------------------------------------------
# 輸出
# ---------------------------------------------------------------------------

def write_srt(cues: list[Cue], zh: list[str], path: Path) -> None:
    lines = []
    for i, (cue, z) in enumerate(zip(cues, zh), 1):
        body = f"{z}\n{cue.text}" if z else cue.text
        lines.append(f"{i}\n{fmt_srt_time(cue.start)} --> {fmt_srt_time(cue.end)}\n{body}\n")
    path.write_text("\n".join(lines), encoding="utf-8")


ASS_HEADER = """[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: ZH,{zh_font},64,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,3,1,2,60,60,40,1
Style: EN,Arial,44,&H00D0D0D0,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,60,60,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


def write_ass(cues: list[Cue], zh: list[str], path: Path, zh_font: str) -> None:
    out = [ASS_HEADER.format(zh_font=zh_font)]
    for cue, z in zip(cues, zh):
        en = cue.text.replace("\n", " ")
        text = f"{z}\\N{{\\rEN}}{en}" if z else f"{{\\rEN}}{en}"
        out.append(f"Dialogue: 0,{fmt_ass_time(cue.start)},{fmt_ass_time(cue.end)},ZH,,0,0,0,,{text}\n")
    path.write_text("".join(out), encoding="utf-8")


def embed_into_mkv(video: Path, sub: Path, out: Path) -> None:
    if not shutil.which("ffmpeg"):
        sys.exit("--embed 需要 ffmpeg，請先安裝（macOS: brew install ffmpeg）")
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(video), "-i", str(sub),
        "-map", "0", "-map", "1", "-c", "copy",
        "-metadata:s:s:0", "language=chi", "-metadata:s:s:0", "title=中英雙語",
        "-disposition:s:0", "default", str(out),
    ]
    subprocess.run(cmd, check=True)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(description="把 YouTube 影片做成中英雙語字幕")
    ap.add_argument("source", help="YouTube 網址，或本機影片路徑")
    ap.add_argument("-o", "--out", default=str(HERE / "output"), help="輸出資料夾（預設 tools/dualsub/output）")
    ap.add_argument("--model", default=os.environ.get("DUALSUB_MODEL", DEFAULT_MODEL), help=f"Claude 模型（預設 {DEFAULT_MODEL}；省錢可用 claude-haiku-5-5）")
    ap.add_argument("--lang", default="zh-TW", choices=["zh-TW", "zh-CN"], help="目標語言（預設 zh-TW）")
    ap.add_argument("--format", default="srt", choices=["srt", "ass", "both"], help="字幕格式（ass 可設定中文大字、英文小字）")
    ap.add_argument("--whisper", action="store_true", help="強制用 faster-whisper 轉錄，不用 YouTube 字幕")
    ap.add_argument("--whisper-model", default="small", help="faster-whisper 模型大小（tiny/base/small/medium/large-v3）")
    ap.add_argument("--embed", action="store_true", help="用 ffmpeg 把字幕封進 .mkv（不重新編碼）")
    ap.add_argument("--max-height", type=int, default=1080, help="下載的最高畫質（預設 1080）")
    ap.add_argument("--workers", type=int, default=4, help="同時送出的翻譯批次數")
    ap.add_argument("--zh-font", default="PingFang TC", help=".ass 中文字型名稱（Windows 可用 Microsoft JhengHei）")
    ap.add_argument("--no-translate", action="store_true", help="只抓英文字幕，不翻譯（除錯用）")
    ap.add_argument("--force", action="store_true", help="忽略已存在的翻譯快取，重新翻譯")
    args = ap.parse_args()

    load_dotenv(HERE / ".env")
    load_dotenv(HERE.parent.parent / ".env")
    outdir = Path(args.out).expanduser().resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    # 1. 影片 + 英文字幕來源
    if is_url(args.source):
        video, sub_path, title = download(args.source, outdir, args.max_height)
    else:
        video = Path(args.source).expanduser().resolve()
        if not video.exists():
            sys.exit(f"找不到檔案：{video}")
        sub_path, title = find_sidecar_subtitle(video), video.stem
        if sub_path:
            log(f"使用同名字幕檔：{sub_path.name}")

    base = video.with_suffix("")
    en_cache = Path(f"{base}.en.json")
    zh_cache = Path(f"{base}.{args.lang}.json")

    # 2. 英文字幕
    if en_cache.exists() and not args.force:
        cues = [Cue(**c) for c in json.loads(en_cache.read_text(encoding="utf-8"))]
        log(f"沿用快取的英文字幕：{en_cache.name}")
    elif sub_path and not args.whisper:
        cues = load_subtitle_file(sub_path)
    else:
        cues = transcribe_with_whisper(video, args.whisper_model)
    if not cues:
        sys.exit("沒有取得任何字幕句子")
    en_cache.write_text(json.dumps([c.__dict__ for c in cues], ensure_ascii=False, indent=1), encoding="utf-8")
    log(f"英文字幕 {len(cues)} 句，長度 {fmt_srt_time(cues[-1].end)}")

    # 3. 翻譯
    if args.no_translate:
        zh = [""] * len(cues)
    elif zh_cache.exists() and not args.force:
        zh = json.loads(zh_cache.read_text(encoding="utf-8"))
        if len(zh) != len(cues):
            sys.exit(f"翻譯快取與英文句數不符，請加 --force 重翻：{zh_cache}")
        log(f"沿用快取的翻譯：{zh_cache.name}")
    else:
        if not (os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN")):
            log("提醒：沒有 ANTHROPIC_API_KEY，將嘗試使用 `ant auth login` 的登入資訊")
        zh = Translator(args.model, args.lang, title).translate_all(cues, args.workers)
        zh_cache.write_text(json.dumps(zh, ensure_ascii=False, indent=1), encoding="utf-8")

    # 4. 輸出
    written: list[Path] = []
    if args.format in ("srt", "both"):
        p = Path(f"{base}.srt")
        write_srt(cues, zh, p)
        written.append(p)
    if args.format in ("ass", "both"):
        p = Path(f"{base}.ass")
        write_ass(cues, zh, p, args.zh_font)
        written.append(p)
    for p in written:
        log(f"字幕已寫入：{p}")

    if args.embed:
        mkv = Path(f"{base}.dualsub.mkv")
        embed_into_mkv(video, written[-1], mkv)
        log(f"已封裝：{mkv}")

    print(f"\n完成！用 IINA / mpv / VLC 打開：\n  {video}\n字幕會自動載入（與影片同名）。")


if __name__ == "__main__":
    main()
