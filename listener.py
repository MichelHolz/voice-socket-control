import sys
import json
import os
import io
from vosk import Model, KaldiRecognizer

# Force UTF-8 encoding for the communication pipe to Node.js
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Disable Vosk spam (Level -2 silences internal C++ logs)
os.environ['VOSK_LOG_LEVEL'] = '-2'
script_dir = os.path.dirname(__file__)

def log_err(msg):
    print(f"VOSK_ERROR: {msg}", file=sys.stderr)

try:
    # 1. Load Model Name from Setup
    model_info_path = os.path.join(script_dir, ".active_model")
    if not os.path.exists(model_info_path):
        raise FileNotFoundError("No .active_model file found. Please run setup.sh.")
        
    with open(model_info_path, "r", encoding='utf-8') as f:
        model_name = f.read().strip()
    model_path = os.path.join(script_dir, model_name)

    # 2. Load Vocabulary from data.json
    config_path = os.path.join(script_dir, "data.json")
    with open(config_path, "r", encoding='utf-8') as f:
        keywords = json.load(f)
        voc_list = list(keywords.keys())
        voc_list.append("[unknown]")
        
        # CRITICAL: ensure_ascii=False keeps Cyrillic characters as real text
        vocabulary = json.dumps(voc_list, ensure_ascii=False)

    model = Model(model_path)
    rec = KaldiRecognizer(model, 16000, vocabulary)

    # Signal to Node.js that we are ready
    print("LISTENER_READY")
    sys.stdout.flush()

except Exception as e:
    log_err(str(e))
    sys.exit(1)

# --- Main Processing Loop ---
while True:
    data = sys.stdin.buffer.read(2000)
    if not data:
        break

    if rec.AcceptWaveform(data):
        res = json.loads(rec.Result())
        phrase = res.get("text", "")
        
        # Match only recognized phrases that exist in our vocabulary
        if phrase and phrase != "[unknown]":
            # Using f-string ensures the TEXT_RECOGNIZED prefix is attached correctly
            print(f"TEXT_RECOGNIZED:{phrase}")
            sys.stdout.flush()
