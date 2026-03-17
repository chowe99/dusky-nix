import os
import time
import signal
import threading
import queue
import argparse
import select
import gc
import subprocess
import soundfile as sf
import re
import hashlib
import numpy as np
import traceback
import shutil
import sys
import uuid
from pathlib import Path
import logging

# ==============================================================================
# VERSION & CONFIGURATION
# ==============================================================================
VERSION = "4.4 (Universal HW + Dual Speed Control)"

ZRAM_MOUNT = Path("/mnt/zram1")
AUDIO_OUTPUT_DIR = (ZRAM_MOUNT / "kokoro_audio") if ZRAM_MOUNT.is_dir() else Path("/tmp/dusky_kokoro_audio")
FIFO_PATH = Path("/tmp/dusky_kokoro.fifo")
PID_FILE = Path("/tmp/dusky_kokoro.pid")
READY_FILE = Path("/tmp/dusky_kokoro.ready")

DEFAULT_VOICE = "af_sarah"
BUILTIN_VOICES = [
    "af_sarah", "af_bella", "af_nicole", "af_sky",
    "am_adam", "am_michael",
    "bf_emma", "bf_isabella",
    "bm_george", "bm_lewis",
]
CUSTOM_VOICES_DIR = Path("~/.local/share/kokoro/voices").expanduser()
PIPER_VOICES_DIR = Path("~/.local/share/piper/voices").expanduser()
VOICE_FILE = Path("/tmp/dusky_kokoro.voice")
VOICE_LIST_FILE = Path("/tmp/dusky_kokoro.voices")

def scan_custom_voices():
    """Scan CUSTOM_VOICES_DIR for .npz files, return list of custom_<name> voice IDs."""
    custom = []
    if CUSTOM_VOICES_DIR.is_dir():
        for f in sorted(CUSTOM_VOICES_DIR.glob("*.npz")):
            custom.append(f"custom_{f.stem}")
    return custom

def scan_piper_voices():
    """Scan PIPER_VOICES_DIR for .onnx files, return list of piper_<name> voice IDs."""
    piper = []
    if PIPER_VOICES_DIR.is_dir():
        for f in sorted(PIPER_VOICES_DIR.glob("*.onnx")):
            piper.append(f"piper_{f.stem}")
    return piper

def get_available_voices():
    """Return combined list of built-in + custom + piper voices."""
    return BUILTIN_VOICES + scan_custom_voices() + scan_piper_voices()

SPEED = 1.0
MPV_SPEED = 1.0  # MPV playback speed control
SAMPLE_RATE = 24000

MAX_BATCH_LEN = 2000
IDLE_TIMEOUT = 10.0
DEDUP_WINDOW = 2.0
QUEUE_SIZE = 5

# ==============================================================================
# LOGGING
# ==============================================================================
logger = logging.getLogger("dusky_daemon")
logger.setLevel(logging.INFO)

c_handler = logging.StreamHandler()
c_handler.setFormatter(logging.Formatter(
    '%(asctime)s - %(threadName)s - %(levelname)s - %(message)s'
))
logger.addHandler(c_handler)


def setup_debug_logging(filepath):
    f_handler = logging.FileHandler(filepath, mode='w')
    f_handler.setFormatter(logging.Formatter(
        '%(asctime)s - %(threadName)s - %(levelname)s - %(funcName)s - %(message)s'
    ))
    f_handler.setLevel(logging.DEBUG)
    logger.addHandler(f_handler)
    logger.setLevel(logging.DEBUG)
    logger.info(f"Debug logging enabled to: {filepath}")


def custom_excepthook(args):
    thread_name = args.thread.name if args.thread else "unknown (GC'd)"
    logger.critical(
        f"UNCAUGHT EXCEPTION in thread {thread_name}: {args.exc_value}"
    )
    traceback.print_tb(args.exc_traceback)


threading.excepthook = custom_excepthook

# ==============================================================================
# TEXT PROCESSING
# ==============================================================================
RE_MARKDOWN_LINK = re.compile(r'\[([^\]]+)\]\([^)]+\)')
RE_URL = re.compile(r'https?://\S+', re.IGNORECASE)
RE_CLEAN = re.compile(r"[^a-zA-Z0-9\s.,!?;:'%\-]")
RE_SENTENCE_SPLIT = re.compile(
    r'(?<!\bMr)(?<!\bMrs)(?<!\bMs)(?<!\bDr)(?<!\bJr)(?<!\bSr)'
    r'(?<!\bProf)(?<!\bVol)(?<!\bNo)(?<!\bVs)(?<!\bEtc)'
    r'\s*([.?!;:]+)\s+'
)


def clean_text(text):
    text = RE_MARKDOWN_LINK.sub(r'\1', text)
    text = RE_URL.sub('Link', text)
    text = RE_CLEAN.sub(' ', text)
    return ' '.join(text.split())


def smart_split(text):
    if not text:
        return []
    chunks = RE_SENTENCE_SPLIT.split(text)
    if len(chunks) == 1:
        return [text.strip()] if text.strip() else []
    sentences = []
    for i in range(0, len(chunks) - 1, 2):
        sentence = chunks[i].strip()
        punctuation = chunks[i + 1].strip() if i + 1 < len(chunks) else ''
        if sentence:
            sentences.append(f"{sentence}{punctuation}")
    if len(chunks) % 2 != 0:
        trailing = chunks[-1].strip()
        if trailing:
            sentences.append(trailing)
    return sentences


def generate_filename_slug(text):
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', text)
    words = clean.split()
    if not words:
        return "audio"
    return "_".join(words[:5]).lower()


def get_next_index(directory):
    max_idx = 0
    if not directory.exists():
        return 1
    for f in directory.glob("*.wav"):
        try:
            parts = f.name.split('_')
            if parts and parts[0].isdigit():
                idx = int(parts[0])
                if idx > max_idx:
                    max_idx = idx
        except Exception:
            pass
    return max_idx + 1


# ==============================================================================
# HARDWARE ENFORCER (UNIVERSAL - FIXED ROCM)
# ==============================================================================
import onnxruntime as rt

_available = rt.get_available_providers()
logger.info(f"ONNX Runtime initialized. Detected Providers: {_available}")


class PatchedInferenceSession(rt.InferenceSession):
    def __init__(self, path_or_bytes, sess_options=None, providers=None, **kwargs):
        if sess_options is None:
            sess_options = rt.SessionOptions()
        
        # 1. Determine Dynamic Providers FIRST
        dynamic_providers = []
        available_set = set(rt.get_available_providers())
        is_gpu = False

        # Check for NVIDIA CUDA
        if 'CUDAExecutionProvider' in available_set:
            logger.info("Configuring for NVIDIA CUDA...")
            is_gpu = True
            cuda_options = {
                'device_id': 0,
                'arena_extend_strategy': 'kSameAsRequested',
                'gpu_mem_limit': 3 * 1024 * 1024 * 1024, # 3GB VRAM limit
                'cudnn_conv_algo_search': 'HEURISTIC',
                'do_copy_in_default_stream': True,
            }
            dynamic_providers.append(('CUDAExecutionProvider', cuda_options))

        # Check for AMD ROCm
        # BUG FIX: Removed 'cudnn_conv_algo_search' (CUDA only)
        # BUG FIX: Added 'gpu_mem_limit'
        elif 'ROCmExecutionProvider' in available_set:
            logger.info("Configuring for AMD ROCm...")
            is_gpu = True
            rocm_options = {
                'device_id': 0,
                'arena_extend_strategy': 'kSameAsRequested',
                'gpu_mem_limit': 3 * 1024 * 1024 * 1024, # 3GB VRAM limit
                'do_copy_in_default_stream': True,
            }
            dynamic_providers.append(('ROCmExecutionProvider', rocm_options))

        # Always add CPU as fallback
        dynamic_providers.append('CPUExecutionProvider')

        # 2. Configure Memory Options (Optimization)
        # BUG FIX: Only disable memory arena if GPU is active
        if is_gpu:
            sess_options.enable_mem_pattern = False
            sess_options.enable_cpu_mem_arena = False
        else:
            logger.info("CPU Mode: Enabling memory arena for performance.")
            sess_options.enable_mem_pattern = True
            sess_options.enable_cpu_mem_arena = True

        sess_options.graph_optimization_level = rt.GraphOptimizationLevel.ORT_ENABLE_ALL

        logger.info(f"Active Provider Stack: {dynamic_providers}")

        super().__init__(
            path_or_bytes, sess_options, providers=dynamic_providers, **kwargs
        )


rt.InferenceSession = PatchedInferenceSession
from kokoro_onnx import Kokoro


# ==============================================================================
# THREAD 1: MPV STREAMER (STREAM ID ARCHITECTURE)
# ==============================================================================
class AudioPlaybackThread(threading.Thread):
    def __init__(self, audio_queue, stop_event):
        super().__init__(name="MPV-Thread")
        self.audio_queue = audio_queue
        self.stop_event = stop_event
        self.active = True
        self.daemon = True
        self._mpv_process = None
        self._lock = threading.Lock()
        self._current_stream_id = None

        if not shutil.which("mpv"):
            logger.critical("MPV executable not found in PATH!")

    def _kill_process(self, proc):
        if proc is None: return
        try:
            if proc.stdin:
                try: proc.stdin.close()
                except Exception: pass
            if proc.poll() is None:
                proc.terminate()
                try: proc.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=1.0)
            else:
                proc.wait()
        except Exception: pass

    def _spawn_mpv(self, sample_rate=None):
        sr = sample_rate or SAMPLE_RATE
        cmd = [
            "mpv", "--no-terminal", "--no-video",
            "--keep-open=no",
            f"--speed={MPV_SPEED}",
            "--demuxer=rawaudio", f"--demuxer-rawaudio-rate={sr}",
            "--demuxer-rawaudio-channels=1", "--demuxer-rawaudio-format=float",
            "--cache=yes", "--cache-secs=300",
            "-"
        ]
        mpv_env = os.environ.copy()
        # Clean env to prevent MPV from inheriting CUDA/ROCm libs if not needed
        mpv_env.pop("LD_LIBRARY_PATH", None) 

        try:
            proc = subprocess.Popen(
                cmd, stdin=subprocess.PIPE, stderr=sys.stderr, stdout=subprocess.DEVNULL,
                env=mpv_env, start_new_session=False, close_fds=True
            )
            logger.info(f"MPV started (PID: {proc.pid})")
            return proc
        except Exception as e:
            logger.error(f"Failed to start MPV: {e}")
            return None

    def _prepare_mpv_for_chunk(self, chunk_stream_id, sample_rate=None):
        with self._lock:
            proc = self._mpv_process
            is_alive = (proc is not None and proc.poll() is None)

            if chunk_stream_id == self._current_stream_id:
                if is_alive: return proc
                else:
                    logger.info("MPV closed mid-stream (User Kill). Halting.")
                    self._mpv_process = None
                    self.stop_event.set()
                    return None

            if is_alive:
                logger.info("New stream ID. Restarting MPV.")
                self._kill_process(proc)

            logger.info(f"Starting new stream ({chunk_stream_id[:8]}...). Spawning MPV.")
            new_proc = self._spawn_mpv(sample_rate)
            self._mpv_process = new_proc
            self._current_stream_id = chunk_stream_id
            return new_proc

    def _finish_stream(self):
        with self._lock:
            self._current_stream_id = None
            proc = self._mpv_process
            self._mpv_process = None
        if proc:
            logger.info(f"Closing MPV stdin (PID: {proc.pid}). Playback finishing.")
            try:
                if proc.stdin: proc.stdin.close()
            except Exception: pass
            threading.Thread(target=self._reap_process, args=(proc,), name="MPV-Reaper", daemon=True).start()

    def _reap_process(self, proc):
        try:
            proc.wait(timeout=600)
            logger.debug(f"MPV (PID: {proc.pid}) exited after playback.")
        except subprocess.TimeoutExpired:
            self._kill_process(proc)
        except Exception: pass

    def _timed_write(self, proc, data, timeout=2.0):
        try: fd = proc.stdin.fileno()
        except Exception: return False
        try: _, wlist, _ = select.select([], [fd], [], timeout)
        except (ValueError, OSError): return False
        if not wlist:
            logger.error("MPV write timed out (Hung?). Killing.")
            self._kill_process(proc)
            return False
        try:
            proc.stdin.write(data)
            proc.stdin.flush()
            return True
        except (BrokenPipeError, OSError): return False

    def run(self):
        try:
            while self.active:
                try: item = self.audio_queue.get(timeout=0.2)
                except queue.Empty:
                    with self._lock:
                        if self._mpv_process and self._mpv_process.poll() is not None:
                            logger.debug("Cleaning up dead MPV handle (Idle).")
                            self._mpv_process = None
                    continue

                if item is None:
                    self._finish_stream()
                    self.audio_queue.task_done()
                    continue

                if self.stop_event.is_set():
                    self.audio_queue.task_done()
                    continue

                samples, sr, stream_id = item
                if samples.dtype != np.float32: samples = samples.astype(np.float32)
                raw_bytes = samples.tobytes()

                try:
                    proc = self._prepare_mpv_for_chunk(stream_id, sample_rate=sr)
                    if not proc:
                        self.audio_queue.task_done()
                        self._drain_queue()
                        continue
                    if not self._timed_write(proc, raw_bytes): raise BrokenPipeError("Write failed")
                except (BrokenPipeError, OSError):
                    logger.warning("MPV Connection Broken. Stopping.")
                    with self._lock:
                        dead_proc = self._mpv_process
                        self._mpv_process = None
                        self._current_stream_id = None
                    self._kill_process(dead_proc)
                    self.stop_event.set()
                    self.audio_queue.task_done()
                    self._drain_queue()
                    continue
                except Exception as e: logger.error(f"Playback Error: {e}")
                self.audio_queue.task_done()
        finally: self.cleanup()

    def _drain_queue(self):
        while True:
            try:
                self.audio_queue.get_nowait()
                self.audio_queue.task_done()
            except queue.Empty: break

    def cleanup(self):
        self.active = False
        with self._lock:
            proc = self._mpv_process
            self._mpv_process = None
            self._current_stream_id = None
        self._kill_process(proc)


# ==============================================================================
# THREAD 2: FIFO READER
# ==============================================================================
class FifoReader(threading.Thread):
    def __init__(self, text_queue, fifo_path):
        super().__init__(name="FIFO-Thread")
        self.text_queue = text_queue
        self.fifo_path = fifo_path
        self.active = True
        self.daemon = True
        self.last_hash = None
        self.last_time = 0
        self.fd = None 

    def run(self):
        if self.fd is not None: fd = self.fd
        else:
            if not self.fifo_path.exists(): os.mkfifo(self.fifo_path)
            fd = os.open(self.fifo_path, os.O_RDWR | os.O_NONBLOCK)

        poll = select.poll()
        poll.register(fd, select.POLLIN)

        while self.active:
            if not poll.poll(500): continue
            try:
                data = b""
                while True:
                    try:
                        chunk = os.read(fd, 65536)
                        if not chunk: break
                        data += chunk
                    except BlockingIOError: break
                if not data: continue
                text = data.decode('utf-8', errors='ignore').strip()
                if not text: continue
                h = hashlib.md5(text.encode()).hexdigest()
                now = time.time()
                if self.last_hash == h and (now - self.last_time) < DEDUP_WINDOW:
                    logger.info("Skipping duplicate.")
                    continue
                self.last_hash = h
                self.last_time = now
                self.text_queue.put(text)
            except OSError: time.sleep(1)
        os.close(fd)


# ==============================================================================
# DAEMON CORE
# ==============================================================================
class DuskyDaemon:
    def __init__(self, debug_file=None):
        self.running = True
        if debug_file: setup_debug_logging(debug_file)
        logger.info(f"Dusky Daemon {VERSION} Initializing...")
        self.audio_queue = queue.Queue(maxsize=QUEUE_SIZE)
        self.text_queue = queue.Queue()
        self.stop_event = threading.Event()
        self.playback = AudioPlaybackThread(self.audio_queue, self.stop_event)
        self.fifo_reader = FifoReader(self.text_queue, FIFO_PATH)
        model_dir = Path(os.environ.get("KOKORO_MODEL_DIR", Path.home() / ".cache" / "kokoro" / "models"))
        self.kokoro = None
        self.model_dir = model_dir
        self.model_path = str(model_dir / "kokoro-v0_19.onnx")
        self.voices_path = str(model_dir / "voices.bin")
        self.voice = self._load_voice()
        self.last_used = 0

    def _load_voice(self):
        """Load saved voice preference, or use default."""
        available = get_available_voices()
        if VOICE_FILE.exists():
            v = VOICE_FILE.read_text().strip()
            if v in available:
                logger.info(f"Loaded saved voice: {v}")
                return v
        return DEFAULT_VOICE

    def _write_voice_list(self):
        """Write current voice list to file for rofi picker."""
        available = get_available_voices()
        VOICE_LIST_FILE.write_text("\n".join(available))
        logger.info(f"Voice list written: {len(available)} voices ({len(available) - len(BUILTIN_VOICES)} custom)")

    def set_voice(self, voice):
        """Switch voice and persist to disk."""
        available = get_available_voices()
        if voice not in available:
            logger.warning(f"Unknown voice '{voice}'. Available: {available}")
            return
        self.voice = voice
        VOICE_FILE.write_text(voice)
        logger.info(f"Voice switched to: {voice}")
        subprocess.run(
            ["notify-send", "-a", "Kokoro TTS", "-t", "2000", "Voice Changed", voice],
            check=False,
        )

    def _ensure_models(self):
        """Download model files if not cached."""
        model_url = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/kokoro-v0_19.onnx"
        voices_url = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/voices.bin"

        self.model_dir.mkdir(parents=True, exist_ok=True)

        for path, url, label in [
            (self.model_path, model_url, "ONNX model"),
            (self.voices_path, voices_url, "voices"),
        ]:
            if not Path(path).exists():
                logger.info(f"Downloading {label}: {url}")
                subprocess.run(
                    ["notify-send", "-a", "Kokoro TTS", "-t", "5000",
                     "Downloading Model", f"First-time download of {label}. This may take a minute..."],
                    check=False,
                )
                import urllib.request
                urllib.request.urlretrieve(url, path)
                logger.info(f"Downloaded {label} to {path}")

    def get_model(self):
        self.last_used = time.time()
        if self.kokoro is None:
            self._ensure_models()
            logger.info("Loading Kokoro...")
            self.kokoro = Kokoro(self.model_path, self.voices_path)
        return self.kokoro

    def check_idle(self):
        if self.kokoro and (time.time() - self.last_used > IDLE_TIMEOUT):
            logger.info("Idle timeout. Cleaning VRAM.")
            del self.kokoro
            self.kokoro = None
            gc.collect()

    def _should_stop(self): return not self.running or self.stop_event.is_set()

    def _setup_fifo(self):
        """Create and open FIFO before readiness."""
        if FIFO_PATH.exists():
            if not FIFO_PATH.is_fifo():
                logger.warning(f"Non-FIFO file at {FIFO_PATH}, removing.")
                FIFO_PATH.unlink()
        if not FIFO_PATH.exists(): os.mkfifo(FIFO_PATH)
        fd = os.open(FIFO_PATH, os.O_RDWR | os.O_NONBLOCK)
        self.fifo_reader.fd = fd
        logger.debug("FIFO created and opened.")

    def _resolve_voice(self):
        """Resolve current voice to a value Kokoro.create() accepts (string or ndarray)."""
        if self.voice.startswith("custom_"):
            name = self.voice[len("custom_"):]
            npz_path = CUSTOM_VOICES_DIR / f"{name}.npz"
            if not npz_path.exists():
                logger.error(f"Custom voice file not found: {npz_path}")
                return None
            data = np.load(str(npz_path))
            # Accept either 'style' key or first array in the npz
            if 'style' in data:
                voice_array = data['style']
            else:
                keys = list(data.keys())
                if not keys:
                    logger.error(f"Custom voice npz is empty: {npz_path}")
                    return None
                voice_array = data[keys[0]]
            logger.info(f"Loaded custom voice '{name}' shape={voice_array.shape}")
            return voice_array.astype(np.float32)
        return self.voice

    def generate_piper(self, text):
        """Generate speech using Piper TTS for piper_* voices."""
        try:
            name = self.voice[len("piper_"):]
            model_path = PIPER_VOICES_DIR / f"{name}.onnx"
            if not model_path.exists():
                logger.error(f"Piper model not found: {model_path}")
                return

            slug = generate_filename_slug(text)
            logger.info(f"Generating (Piper): '{slug}'")
            current_stream_id = str(uuid.uuid4())

            try: AUDIO_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            except OSError as e: logger.warning(f"Cannot create audio output dir: {e}")

            # Piper outputs raw 16-bit signed PCM at its model's sample rate (typically 22050)
            # Read sample rate from model config
            config_path = PIPER_VOICES_DIR / f"{name}.onnx.json"
            piper_sr = 22050
            if config_path.exists():
                import json
                with open(config_path) as f:
                    cfg = json.load(f)
                piper_sr = cfg.get("audio", {}).get("sample_rate", 22050)

            cmd = ["piper", "--model", str(model_path), "--output-raw",
                   "--length-scale", str(1.0 / SPEED)]
            proc = subprocess.Popen(
                cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            proc.stdin.write(text.encode("utf-8"))
            proc.stdin.close()

            # Read raw PCM output in chunks
            all_audio = []
            chunk_size = piper_sr * 2  # 1 second of 16-bit mono
            while not self._should_stop():
                raw = proc.stdout.read(chunk_size)
                if not raw:
                    break
                # Convert 16-bit PCM to float32
                audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
                all_audio.append(audio)
                while not self._should_stop():
                    try:
                        self.audio_queue.put((audio, piper_sr, current_stream_id), timeout=0.2)
                        break
                    except queue.Full: continue

            proc.wait()

            if all_audio:
                try: self.audio_queue.put(None, timeout=5.0)
                except queue.Full: logger.warning("Could not send end-of-stream sentinel.")
                try:
                    idx = get_next_index(AUDIO_OUTPUT_DIR)
                    combined = np.concatenate(all_audio)
                    wav_path = AUDIO_OUTPUT_DIR / f"{idx}_{slug}.wav"
                    sf.write(str(wav_path), combined, piper_sr)
                    logger.info(f"Saved: {wav_path.name}")
                except Exception as e: logger.error(f"Failed to save WAV: {e}")
        except Exception as e:
            logger.error(f"Piper Generation Error: {e}")

    def generate(self, text):
        if self.voice.startswith("piper_"):
            return self.generate_piper(text)
        try:
            model = self.get_model()
            voice_param = self._resolve_voice()
            if voice_param is None:
                logger.error("Could not resolve voice, falling back to default")
                voice_param = DEFAULT_VOICE
            slug = generate_filename_slug(text)
            sentences = smart_split(text)
            if not sentences: return
            logger.info(f"Generating: '{slug}' ({len(sentences)} sentences)")
            current_stream_id = str(uuid.uuid4())

            try: AUDIO_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            except OSError as e: logger.warning(f"Cannot create audio output dir: {e}")
            idx = get_next_index(AUDIO_OUTPUT_DIR)
            all_audio = []
            final_sr = SAMPLE_RATE

            for i, sentence in enumerate(sentences):
                if self._should_stop(): break
                logger.debug(f"  Sentence {i+1}/{len(sentences)}: {sentence[:60]}...")
                audio, sr = model.create(sentence, voice=voice_param, speed=SPEED, lang="en-us")
                if audio is None: continue
                final_sr = sr
                all_audio.append(audio)
                while not self._should_stop():
                    try:
                        self.audio_queue.put((audio, sr, current_stream_id), timeout=0.2)
                        break
                    except queue.Full: continue

            if all_audio:
                try: self.audio_queue.put(None, timeout=5.0)
                except queue.Full: logger.warning("Could not send end-of-stream sentinel.")
                try:
                    combined = np.concatenate(all_audio)
                    wav_path = AUDIO_OUTPUT_DIR / f"{idx}_{slug}.wav"
                    sf.write(str(wav_path), combined, final_sr)
                    logger.info(f"Saved: {wav_path.name}")
                except Exception as e: logger.error(f"Failed to save WAV: {e}")
        except Exception as e:
            logger.error(f"Generation Error: {e}")
            self.kokoro = None

    def start(self):
        signal.signal(signal.SIGTERM, lambda s, f: self.stop())
        signal.signal(signal.SIGINT, lambda s, f: self.stop())
        PID_FILE.write_text(str(os.getpid()))
        self._setup_fifo()
        self._write_voice_list()
        self.playback.start()
        self.fifo_reader.start()
        READY_FILE.touch()
        logger.info(f"Daemon Ready (PID: {os.getpid()})")
        try:
            while self.running:
                try:
                    text = self.text_queue.get(timeout=0.5)
                    self.stop_event.clear()
                    # Handle commands
                    if text.startswith("!voice "):
                        self.set_voice(text[7:].strip())
                        self.text_queue.task_done()
                        continue
                    clean = clean_text(text)
                    if clean: self.generate(clean)
                    if self.stop_event.is_set():
                        logger.info("User interrupted playback. Flushing...")
                        drained = 0
                        while not self.text_queue.empty():
                            try:
                                self.text_queue.get_nowait()
                                self.text_queue.task_done()
                                drained += 1
                            except queue.Empty: break
                        time.sleep(1.0)
                        while not self.text_queue.empty():
                            try:
                                self.text_queue.get_nowait()
                                self.text_queue.task_done()
                                drained += 1
                            except queue.Empty: break
                        if drained > 0: logger.info(f"Flushed {drained} items.")
                    self.text_queue.task_done()
                except queue.Empty: self.check_idle()
        finally: self.cleanup()

    def stop(self):
        self.running = False
        self.stop_event.set()

    def cleanup(self):
        logger.info("Shutting down...")
        self.running = False
        self.stop_event.set()
        self.fifo_reader.active = False
        self.playback.cleanup()
        for p in (FIFO_PATH, PID_FILE, READY_FILE, VOICE_LIST_FILE):
            try: p.unlink(missing_ok=True)
            except Exception: pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--daemon", action="store_true")
    parser.add_argument("--log-level", default="INFO")
    parser.add_argument("--debug-file", help="Path to write debug log")
    args = parser.parse_args()
    log_level = os.environ.get("DUSKY_LOG_LEVEL", args.log_level).upper()
    if hasattr(logging, log_level): logger.setLevel(getattr(logging, log_level))
    debug_path = args.debug_file or os.environ.get("DUSKY_LOG_FILE")
    AUDIO_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.daemon: DuskyDaemon(debug_path).start()
    else: print("Run with --daemon")
