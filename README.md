# Voice Socket Control

## Description

### What
Voice Socket Control is a localized, high-performance voice recognition interface. It maps spoken phrases to system commands (CMDs) using a lightweight offline AI model. It is specifically optimized for Raspberry Pi to control hardware like Energenie USB sockets (`sispmctl`).

### Why
This is a **Privacy-First** solution. By processing all audio locally, it eliminates the latency and data-privacy concerns of cloud-based assistants. It is designed to be an "always-on" appliance that is resilient to reboots and network changes.

---

## Technical Architecture

The system utilizes a **Triple-Process Pipe** to ensure near-instantaneous response times on limited ARM hardware:

1.  **ALSA (`arecord`)**: Captures raw audio directly from the hardware. Using `plughw` ensures automatic resampling and hardware compatibility.
2.  **Node.js (Controller)**: The central "Brain" that manages data streams, handles command mapping, and manages the lifecycle of the AI worker.
3.  **Vosk (Python AI)**: A lightweight, offline engine. It uses a **Dynamic Vocabulary**—it only listens for the specific phrases defined in your `data.json`, which drastically reduces CPU usage and increases accuracy.



---

## Environment-Specific Setup

### Raspberry Pi (Headless / Dedicated)
The installer will **Mask** PulseAudio. This is the preferred method for a dedicated Pi as it ensures the Node.js script has exclusive, low-latency access to the microphone.

### Desktop Linux (PC)
**Do Not Mask PulseAudio** unless you want to lose system sounds and volume keys.
* **Solution**: Use `pavucontrol` to set the USB Microphone profile to **"Off"**. This hides the mic from PulseAudio so the ALSA script can grab it, while keeping your speakers/headphones working normally.

---

## Setup & Installation

1.  **Clone the Repository**:
    ```bash
    git clone [https://github.com/MichelHolz/voice-socket-control.git](https://github.com/MichelHolz/voice-socket-control.git)
    cd voice-socket-control
    ```

2.  **Run the Installer**:
    ```bash
    chmod +x setup.sh
    ./setup.sh
    ```
    *Select your language, opt-in for `sispmctl` if needed, and follow the silence prompt for calibration.*

3.  **Configuration (`data.json`)**:
    Map your phrases to shell commands. Use **lowercase** for keys:
    ```json
    {
      "да будет свет": "sispmctl -o 1",
      "да грянет тьма": "sispmctl -f 1",
      "lux lucet": "aplay /home/pi/notif.wav"
    }
    ```

4.  **Execution**:
    ```bash
    node run.js
    ```

---

## Preventing False Triggers (Best Practices)

Voice recognition in noisy environments (TV, multiple people talking) can lead to "phantom" commands. Follow these rules for 99% accuracy:

* **The 3-Syllable Rule**: Avoid single words like "on" or "light". Use phrases like "Activate the system" or "Lumen fiat". Longer rhythmic patterns are much harder for background noise to accidentally mimic.
* **Hardware Gain**: Use `alsamixer` (F6 -> Select Mic) to set **Capture** gain to roughly **60%**. If the gain is too high, the AI hears "echoes" and background whispers.
* **Acoustic Shadow**: Place the microphone away from fans or speakers.
* **Phonetic Variety**: Use phrases with distinct, sharp consonants (K, T, P, X, B).

---

## Troubleshooting

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **Device Busy** | PulseAudio is locking the mic. | Mask PA (Pi) or set Mic profile to Off (Desktop). |
| **Unicode Errors** | Encoding mismatch in JSON. | Ensure `data.json` is saved in **UTF-8**. |
| **No Detection** | Mic Card changed index. | The script auto-detects, but check `arecord -l` if it fails. |
| **Slow Response** | Massive Model or CPU load. | Ensure you selected a **"small"** model during setup. |

---

## Maintenance & Logs
View live recognition and execution logs via:
* **Manual**: `node run.js` (outputs color-coded logs)
* **Systemd**: `journalctl -u voice-control.service -f`
