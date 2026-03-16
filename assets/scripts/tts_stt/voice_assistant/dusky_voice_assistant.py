import os
import time
import signal
import threading
import queue
import argparse
import select
import gc
import subprocess
import traceback
import shutil
import json
import struct
import tempfile
import re
from pathlib import Path
import logging

# ==============================================================================
# CONFIGURATION
# ==============================================================================
VERSION = "1.0 (Voice Assistant + Wake Word)"

# Environment-configurable settings
WAKE_WORD = os.environ.get("DUSKY_WAKE_WORD", "hey_jarvis")
VOICE_MODE = os.environ.get("DUSKY_VOICE_MODE", "local")
FOLLOWUP_TIMEOUT = float(os.environ.get("DUSKY_FOLLOWUP_TIMEOUT", "8"))
MAX_TURNS = int(os.environ.get("DUSKY_MAX_TURNS", "10"))
LLM_COMMAND = os.environ.get("DUSKY_LLM_COMMAND", "claude")
CHIME_SOUND = os.environ.get("DUSKY_CHIME_SOUND", "")
STT_MODEL_NAME = os.environ.get("DUSKY_STT_MODEL", "nemo-parakeet-tdt-0.6b-v2")
STT_QUANTIZATION = os.environ.get("DUSKY_STT_QUANTIZATION", "int8")

# Silence detection
SILENCE_THRESHOLD = 500  # RMS threshold for silence
SILENCE_DURATION = 2.0   # Seconds of silence to stop recording
SAMPLE_RATE = 16000
CHANNELS = 1

# File paths
ZRAM_MOUNT = Path("/mnt/zram1")
AUDIO_DIR = (ZRAM_MOUNT / "voice_assistant") if ZRAM_MOUNT.is_dir() else Path("/tmp/dusky_voice_assistant_audio")
FIFO_PATH = Path("/tmp/dusky_voice_assistant.fifo")
PID_FILE = Path("/tmp/dusky_voice_assistant.pid")
READY_FILE = Path("/tmp/dusky_voice_assistant.ready")

# Kokoro TTS integration
KOKORO_FIFO = Path("/tmp/dusky_kokoro.fifo")
KOKORO_PID_FILE = Path("/tmp/dusky_kokoro.pid")

IDLE_TIMEOUT = 30.0  # Longer than STT — voice assistant is more interactive
WAKE_THRESHOLD = 0.5  # openwakeword confidence threshold

# ==============================================================================
# LOGGING
# ==============================================================================
logger = logging.getLogger("dusky_voice")
logger.setLevel(logging.INFO)
c_handler = logging.StreamHandler()
c_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(c_handler)

def custom_excepthook(args):
    logger.critical(f"UNCAUGHT EXCEPTION: {args.exc_value}")
    traceback.print_tb(args.exc_traceback)

threading.excepthook = custom_excepthook

def notify(title, message, critical=False):
    if not shutil.which("notify-send"):
        logger.error(f"notify-send missing: {title} - {message}")
        return
    cmd = ["notify-send", "-a", "Dusky Voice", "-t", "3000"]
    if critical:
        cmd.extend(["-u", "critical"])
    cmd.extend([title, message])
    try:
        subprocess.run(cmd, check=False)
    except Exception as e:
        logger.error(f"notify-send failed: {e}")

# ==============================================================================
# HARDWARE ENFORCER (same pattern as Parakeet)
# ==============================================================================
import onnxruntime as rt

class PatchedInferenceSession(rt.InferenceSession):
    def __init__(self, path_or_bytes, sess_options=None, providers=None, **kwargs):
        if sess_options is None:
            sess_options = rt.SessionOptions()

        p_names = []
        p_opts = []
        available_set = set(rt.get_available_providers())
        is_gpu = False

        if 'CUDAExecutionProvider' in available_set:
            is_gpu = True
            p_names.append('CUDAExecutionProvider')
            p_opts.append({
                'device_id': 0,
                'arena_extend_strategy': 'kSameAsRequested',
                'gpu_mem_limit': 6 * 1024 * 1024 * 1024,
                'cudnn_conv_algo_search': 'HEURISTIC',
                'do_copy_in_default_stream': True,
            })
        elif 'MIGraphXExecutionProvider' in available_set:
            is_gpu = True
            p_names.append('MIGraphXExecutionProvider')
            p_opts.append({'device_id': 0})
        elif 'ROCmExecutionProvider' in available_set:
            is_gpu = True
            p_names.append('ROCmExecutionProvider')
            p_opts.append({
                'device_id': 0,
                'arena_extend_strategy': 'kSameAsRequested',
                'gpu_mem_limit': 3 * 1024 * 1024 * 1024,
                'do_copy_in_default_stream': True,
            })

        p_names.append('CPUExecutionProvider')
        p_opts.append({})

        if is_gpu:
            sess_options.enable_mem_pattern = False
            sess_options.enable_cpu_mem_arena = False
        else:
            sess_options.enable_mem_pattern = True
            sess_options.enable_cpu_mem_arena = True

        sess_options.graph_optimization_level = rt.GraphOptimizationLevel.ORT_ENABLE_ALL
        kwargs.pop('provider_options', None)

        super().__init__(path_or_bytes, sess_options, providers=p_names, provider_options=p_opts, **kwargs)

rt.InferenceSession = PatchedInferenceSession
import onnx_asr

# ==============================================================================
# STATE MACHINE
# ==============================================================================
class State:
    IDLE = "IDLE"
    WAKE_DETECTED = "WAKE_DETECTED"
    RECORDING = "RECORDING"
    TRANSCRIBING = "TRANSCRIBING"
    THINKING = "THINKING"
    SPEAKING = "SPEAKING"
    LISTENING_FOLLOWUP = "LISTENING_FOLLOWUP"

# ==============================================================================
# THREAD: WAKE WORD DETECTION
# ==============================================================================
class WakeWordThread(threading.Thread):
    def __init__(self, wake_callback):
        super().__init__(name="WakeWord", daemon=True)
        self.wake_callback = wake_callback
        self.active = True
        self.paused = False
        self._oww_model = None

    def _get_model(self):
        if self._oww_model is None:
            from openwakeword.model import Model
            self._oww_model = Model(wakeword_models=[WAKE_WORD], inference_framework="onnx")
            logger.info(f"Wake word model loaded: {WAKE_WORD}")
        return self._oww_model

    def run(self):
        import sounddevice as sd
        import numpy as np

        chunk_size = 1280  # 80ms at 16kHz (openwakeword expects this)
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype='int16',
            blocksize=chunk_size,
        )
        stream.start()
        logger.info("Wake word listener started")

        try:
            while self.active:
                if self.paused:
                    time.sleep(0.1)
                    continue

                audio_data, overflowed = stream.read(chunk_size)
                if overflowed:
                    continue

                try:
                    model = self._get_model()
                    prediction = model.predict(audio_data.flatten())

                    for mdl_name in prediction:
                        if prediction[mdl_name] >= WAKE_THRESHOLD:
                            logger.info(f"Wake word detected! ({mdl_name}: {prediction[mdl_name]:.2f})")
                            model.reset()
                            self.wake_callback()
                            break
                except Exception as e:
                    logger.error(f"Wake word inference error: {e}")
                    time.sleep(1)
        finally:
            stream.stop()
            stream.close()

# ==============================================================================
# THREAD: FIFO COMMAND READER
# ==============================================================================
class FifoReader(threading.Thread):
    def __init__(self, command_queue, fifo_path):
        super().__init__(name="FIFO", daemon=True)
        self.command_queue = command_queue
        self.fifo_path = fifo_path
        self.active = True

    def run(self):
        if not self.fifo_path.exists():
            os.mkfifo(self.fifo_path)
        fd = os.open(self.fifo_path, os.O_RDWR | os.O_NONBLOCK)
        poll = select.poll()
        poll.register(fd, select.POLLIN)

        while self.active:
            if not poll.poll(500):
                continue
            try:
                data = b""
                while True:
                    try:
                        chunk = os.read(fd, 4096)
                        if not chunk:
                            break
                        data += chunk
                    except BlockingIOError:
                        break

                if data:
                    for line in data.decode('utf-8', errors='ignore').splitlines():
                        cmd = line.strip().upper()
                        if cmd:
                            self.command_queue.put(cmd)
            except OSError:
                time.sleep(1)
        os.close(fd)

# ==============================================================================
# AUDIO RECORDING WITH SILENCE DETECTION
# ==============================================================================
def record_until_silence(output_path, timeout=30):
    """Record from mic via pw-record, stop after silence or timeout.

    Returns True if speech was captured, False if only silence.
    """
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    proc = subprocess.Popen(
        ["pw-record", "--target", "@DEFAULT_AUDIO_SOURCE@",
         "--rate", str(SAMPLE_RATE), "--channels", str(CHANNELS),
         "--format=s16", str(output_path)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    logger.info("Recording started...")
    start_time = time.time()
    silence_start = None
    has_speech = False

    # Monitor audio levels by reading the file as it grows
    # Give pw-record a moment to start writing
    time.sleep(0.3)

    try:
        while proc.poll() is None:
            elapsed = time.time() - start_time
            if elapsed > timeout:
                logger.info("Recording timeout reached")
                break

            # Read the latest audio data from the file to check levels
            try:
                if output_path.exists():
                    file_size = output_path.stat().st_size
                    if file_size > 44:  # WAV header
                        with open(output_path, 'rb') as f:
                            f.seek(max(44, file_size - SAMPLE_RATE * 2))  # Last ~1s
                            raw = f.read()
                        if len(raw) >= 2:
                            samples = struct.unpack(f'<{len(raw)//2}h', raw)
                            rms = (sum(s*s for s in samples) / len(samples)) ** 0.5

                            if rms > SILENCE_THRESHOLD:
                                has_speech = True
                                silence_start = None
                            elif has_speech:
                                if silence_start is None:
                                    silence_start = time.time()
                                elif time.time() - silence_start >= SILENCE_DURATION:
                                    logger.info("Silence detected, stopping recording")
                                    break
            except (OSError, struct.error):
                pass

            time.sleep(0.2)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()

    return has_speech

# ==============================================================================
# DAEMON CORE
# ==============================================================================
class DuskyVoiceAssistant:
    def __init__(self):
        self.running = True
        self.state = State.IDLE
        self.conversation = []  # List of {"role": "user"/"assistant", "text": "..."}
        self.command_queue = queue.Queue(maxsize=10)
        self.wake_event = threading.Event()
        self.listening_enabled = True

        logger.info(f"Dusky Voice Assistant {VERSION} Initializing...")
        logger.info(f"Wake word: {WAKE_WORD}, LLM: {LLM_COMMAND}, Follow-up: {FOLLOWUP_TIMEOUT}s")

        # STT model (lazy loaded)
        self.stt_model = None
        self.last_stt_used = 0

        # Threads
        self.fifo_reader = FifoReader(self.command_queue, FIFO_PATH)
        self.wake_thread = WakeWordThread(self._on_wake)

    # --- STT Model Management (same pattern as Parakeet) ---

    def _model_is_cached(self):
        try:
            from huggingface_hub import try_to_load_from_cache
            result = try_to_load_from_cache(f"onnx-community/{STT_MODEL_NAME}", "model.onnx")
            return result is not None and isinstance(result, str)
        except Exception:
            return False

    def get_stt_model(self):
        self.last_stt_used = time.time()
        if self.stt_model is None:
            if not self._model_is_cached():
                notify("Downloading Model", f"First-time download of {STT_MODEL_NAME}...")
                logger.info(f"Model not cached — downloading {STT_MODEL_NAME}...")
            logger.info(f"Loading {STT_MODEL_NAME} (Quantization: {STT_QUANTIZATION}) into VRAM...")
            self.stt_model = onnx_asr.load_model(STT_MODEL_NAME, quantization=STT_QUANTIZATION)
        return self.stt_model

    def check_stt_idle(self):
        if self.stt_model and (time.time() - self.last_stt_used > IDLE_TIMEOUT):
            logger.info(f"STT idle timeout ({IDLE_TIMEOUT}s). Unloading model.")
            del self.stt_model
            self.stt_model = None
            gc.collect()

    # --- Transcription ---

    def transcribe(self, audio_path):
        """Transcribe audio file, return text string."""
        try:
            model = self.get_stt_model()
            res = model.recognize(str(audio_path))
            text = (res[0] if isinstance(res, list) else res).strip()
            del res
            gc.collect()
            return text if text else None
        except Exception as e:
            logger.error(f"Transcription error: {e}")
            self.stt_model = None
            return None

    # --- LLM Interaction ---

    def build_prompt(self, user_text):
        """Build prompt with conversation history for the LLM."""
        system_context = (
            "You are Dusky, a helpful voice assistant. "
            "Keep responses concise and conversational — they will be spoken aloud via TTS. "
            "Avoid markdown formatting, code blocks, or long lists. "
            "Use natural spoken language."
        )

        parts = [system_context, ""]

        # Add conversation history
        for turn in self.conversation[-(MAX_TURNS * 2):]:
            role = "User" if turn["role"] == "user" else "Dusky"
            parts.append(f"{role}: {turn['text']}")

        parts.append(f"User: {user_text}")
        parts.append("Dusky:")

        return "\n".join(parts)

    def query_llm(self, user_text):
        """Send user text to LLM and return response."""
        prompt = self.build_prompt(user_text)

        try:
            # Unset CLAUDECODE to avoid nesting detection if launched from Claude Code
            env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
            result = subprocess.run(
                [LLM_COMMAND, "-p", prompt, "--no-session-persistence", "--output-format", "text"],
                capture_output=True, text=True, timeout=60, env=env,
            )
            if result.returncode != 0:
                err_msg = (result.stderr or result.stdout or "unknown error").strip()[:200]
                logger.error(f"LLM error (rc={result.returncode}): {err_msg}")
                notify("Voice Assistant", f"LLM error: {err_msg[:100]}", critical=True)
                return None

            response = result.stdout.strip()
            # Remove any "Dusky:" prefix the model might echo
            if response.lower().startswith("dusky:"):
                response = response[6:].strip()
            return response if response else None

        except subprocess.TimeoutExpired:
            logger.error("LLM request timed out")
            return None
        except FileNotFoundError:
            logger.error(f"LLM command not found: {LLM_COMMAND}")
            notify("Voice Assistant Error", f"LLM not found: {LLM_COMMAND}", critical=True)
            return None

    # --- TTS Output (via Kokoro) ---

    def speak(self, text):
        """Send text to Kokoro TTS daemon via FIFO."""
        if not KOKORO_FIFO.exists():
            logger.warning("Kokoro FIFO not found — starting TTS daemon")
            subprocess.run(
                ["systemctl", "--user", "start", "dusky-kokoro-tts.service"],
                check=False, capture_output=True,
            )
            # Wait for ready
            for _ in range(100):
                if KOKORO_FIFO.exists():
                    break
                time.sleep(0.1)

        if not KOKORO_FIFO.exists():
            logger.error("Kokoro TTS daemon unavailable")
            notify("Voice Assistant", "TTS daemon not available", critical=True)
            return

        # Clean text for TTS
        clean = re.sub(r'[*_`#\[\]]', '', text)
        clean = re.sub(r'https?://\S+', 'a link', clean)
        clean = clean.strip()

        if not clean:
            return

        try:
            # Non-blocking write to FIFO
            proc = subprocess.Popen(
                ["bash", "-c", f"printf '%s\\n' {repr(clean)} > {KOKORO_FIFO}"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            proc.wait(timeout=5)
            logger.info(f"Sent to TTS: {clean[:60]}...")
        except subprocess.TimeoutExpired:
            proc.kill()
            logger.error("TTS FIFO write timed out")

    def wait_for_speech_done(self):
        """Wait for Kokoro TTS to finish speaking.

        Polls the Kokoro PID to check if it's still processing.
        Simple heuristic: wait a base time proportional to text length.
        """
        # Give TTS time to start processing
        time.sleep(0.5)

        # Poll: check if mpv is playing audio for Kokoro
        max_wait = 120  # Never wait more than 2 minutes
        waited = 0
        while waited < max_wait:
            result = subprocess.run(
                ["pgrep", "-f", "mpv.*kokoro"],
                capture_output=True, check=False,
            )
            if result.returncode != 0:
                # mpv not running for kokoro — speech probably done
                time.sleep(0.5)  # Small buffer
                break
            time.sleep(0.5)
            waited += 0.5

    # --- Chime ---

    def play_chime(self):
        """Play activation chime sound."""
        chime = CHIME_SOUND
        if not chime or not Path(chime).exists():
            # Generate a simple chime via shell
            try:
                subprocess.run(
                    ["bash", "-c",
                     "play -qn synth 0.15 sine 880 sine 1100 remix - fade t 0 0.15 0.05 2>/dev/null || true"],
                    timeout=2, check=False,
                )
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
            return

        try:
            subprocess.run(["mpv", "--no-terminal", "--no-video", chime],
                         timeout=3, check=False,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # --- Wake Word Callback ---

    def _on_wake(self):
        """Called by WakeWordThread when wake word is detected."""
        if not self.listening_enabled:
            return
        self.wake_event.set()

    # --- Command Processing ---

    def process_commands(self):
        """Process any pending FIFO commands. Returns True if should continue."""
        try:
            while True:
                cmd = self.command_queue.get_nowait()
                logger.info(f"Command: {cmd}")

                if cmd == "STOP":
                    self.running = False
                    return False
                elif cmd == "RESET":
                    self.conversation.clear()
                    notify("Voice Assistant", "Conversation reset")
                    logger.info("Conversation history cleared")
                elif cmd == "TOGGLE":
                    self.listening_enabled = not self.listening_enabled
                    status = "enabled" if self.listening_enabled else "disabled"
                    self.wake_thread.paused = not self.listening_enabled
                    notify("Voice Assistant", f"Listening {status}")
                    logger.info(f"Listening {status}")
                elif cmd == "ACTIVATE":
                    # Manual activation (skip wake word)
                    self.wake_event.set()

                self.command_queue.task_done()
        except queue.Empty:
            pass
        return True

    # --- Main Conversation Loop ---

    def handle_conversation_turn(self):
        """Handle a single conversation turn: record → transcribe → LLM → speak."""
        # Record speech
        self.state = State.RECORDING
        audio_path = AUDIO_DIR / f"voice_{int(time.time())}.wav"
        notify("Voice Assistant", "Listening...")

        has_speech = record_until_silence(audio_path)

        if not has_speech:
            logger.info("No speech detected in recording")
            try:
                audio_path.unlink(missing_ok=True)
            except OSError:
                pass
            return False

        # Transcribe
        self.state = State.TRANSCRIBING
        logger.info("Transcribing...")
        text = self.transcribe(audio_path)

        try:
            audio_path.unlink(missing_ok=True)
        except OSError:
            pass

        if not text:
            logger.info("Transcription returned empty")
            notify("Voice Assistant", "Didn't catch that")
            return False

        logger.info(f"User said: {text}")
        notify("Voice Assistant", f"You: {text}")

        # Add to conversation
        self.conversation.append({"role": "user", "text": text})

        # Query LLM
        self.state = State.THINKING
        logger.info("Thinking...")
        response = self.query_llm(text)

        if not response:
            notify("Voice Assistant", "Couldn't get a response", critical=True)
            return False

        logger.info(f"Response: {response[:100]}...")
        self.conversation.append({"role": "assistant", "text": response})

        # Trim conversation history
        while len(self.conversation) > MAX_TURNS * 2:
            self.conversation.pop(0)

        # Speak response
        self.state = State.SPEAKING
        self.speak(response)
        self.wait_for_speech_done()

        return True

    # --- Main Loop ---

    def start(self):
        signal.signal(signal.SIGTERM, lambda s, f: self.stop())
        signal.signal(signal.SIGINT, lambda s, f: self.stop())

        AUDIO_DIR.mkdir(parents=True, exist_ok=True)
        PID_FILE.write_text(str(os.getpid()))
        if FIFO_PATH.exists() and not FIFO_PATH.is_fifo():
            FIFO_PATH.unlink()

        self.fifo_reader.start()
        self.wake_thread.start()
        READY_FILE.touch()
        logger.info(f"Daemon Ready (PID: {os.getpid()})")
        notify("Voice Assistant", f"Ready! Say '{WAKE_WORD.replace('_', ' ')}' to activate")

        try:
            while self.running:
                if not self.process_commands():
                    break

                # Wait for wake word or command
                self.state = State.IDLE
                if self.wake_event.wait(timeout=1.0):
                    self.wake_event.clear()

                    if not self.running:
                        break

                    # Wake word detected — start conversation
                    self.state = State.WAKE_DETECTED
                    logger.info("Wake detected — starting conversation")
                    self.wake_thread.paused = True  # Pause wake detection during conversation

                    self.play_chime()

                    # Conversation loop with follow-up
                    while self.running:
                        if not self.process_commands():
                            break

                        success = self.handle_conversation_turn()

                        if not success:
                            break

                        # Listen for follow-up
                        self.state = State.LISTENING_FOLLOWUP
                        logger.info(f"Listening for follow-up ({FOLLOWUP_TIMEOUT}s timeout)...")
                        notify("Voice Assistant", "Listening for follow-up...")

                        # Record with shorter timeout for follow-up
                        followup_audio = AUDIO_DIR / f"followup_{int(time.time())}.wav"

                        # Use pw-record with a timeout
                        proc = subprocess.Popen(
                            ["pw-record", "--target", "@DEFAULT_AUDIO_SOURCE@",
                             "--rate", str(SAMPLE_RATE), "--channels", str(CHANNELS),
                             "--format=s16", str(followup_audio)],
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )

                        # Wait for speech or timeout
                        followup_start = time.time()
                        has_followup_speech = False
                        silence_since = time.time()

                        while time.time() - followup_start < FOLLOWUP_TIMEOUT:
                            if not self.running:
                                break

                            # Check for commands
                            if not self.process_commands():
                                break

                            try:
                                if followup_audio.exists():
                                    file_size = followup_audio.stat().st_size
                                    if file_size > 44:
                                        with open(followup_audio, 'rb') as f:
                                            f.seek(max(44, file_size - SAMPLE_RATE * 2))
                                            raw = f.read()
                                        if len(raw) >= 2:
                                            samples = struct.unpack(f'<{len(raw)//2}h', raw)
                                            rms = (sum(s*s for s in samples) / len(samples)) ** 0.5

                                            if rms > SILENCE_THRESHOLD:
                                                has_followup_speech = True
                                                silence_since = time.time()
                                            elif has_followup_speech and time.time() - silence_since >= SILENCE_DURATION:
                                                break
                            except (OSError, struct.error):
                                pass

                            time.sleep(0.2)

                        # Stop recording
                        proc.terminate()
                        try:
                            proc.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            proc.kill()
                            proc.wait()

                        if not has_followup_speech:
                            logger.info("No follow-up detected, returning to idle")
                            try:
                                followup_audio.unlink(missing_ok=True)
                            except OSError:
                                pass
                            break

                        # Transcribe follow-up
                        self.state = State.TRANSCRIBING
                        text = self.transcribe(followup_audio)
                        try:
                            followup_audio.unlink(missing_ok=True)
                        except OSError:
                            pass

                        if not text:
                            logger.info("Follow-up transcription empty, returning to idle")
                            break

                        logger.info(f"Follow-up: {text}")
                        notify("Voice Assistant", f"You: {text}")

                        # Add to conversation and get response
                        self.conversation.append({"role": "user", "text": text})

                        self.state = State.THINKING
                        response = self.query_llm(text)

                        if not response:
                            break

                        logger.info(f"Response: {response[:100]}...")
                        self.conversation.append({"role": "assistant", "text": response})

                        while len(self.conversation) > MAX_TURNS * 2:
                            self.conversation.pop(0)

                        self.state = State.SPEAKING
                        self.speak(response)
                        self.wait_for_speech_done()

                    # Re-enable wake word detection
                    self.wake_thread.paused = not self.listening_enabled
                    self.state = State.IDLE
                    logger.info("Conversation ended, returning to idle")

                else:
                    # Timeout — check idle
                    self.check_stt_idle()

        finally:
            self.cleanup()

    def stop(self):
        self.running = False
        self.wake_event.set()  # Unblock wait

    def cleanup(self):
        logger.info("Shutting down...")
        self.running = False
        self.wake_thread.active = False
        self.fifo_reader.active = False
        for p in (FIFO_PATH, PID_FILE, READY_FILE):
            try:
                p.unlink(missing_ok=True)
            except Exception:
                pass

# ==============================================================================
# ENTRY POINT
# ==============================================================================
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Dusky Voice Assistant Daemon")
    parser.add_argument("--daemon", action="store_true", help="Run as daemon")
    args = parser.parse_args()
    if args.daemon:
        DuskyVoiceAssistant().start()
    else:
        print("Run with --daemon")
