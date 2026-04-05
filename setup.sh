#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${BLUE}       VOICE CONTROL SYSTEM - FINAL SETUP           ${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}${BOLD}>>> $1${NC}"
}

clear
print_banner

# --- 1. Environment & Hardware Detection ---
print_section "Detecting System & Hardware..."
IS_PI=false
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    IS_PI=true
    echo -e "${GREEN}✔ Raspberry Pi hardware detected.${NC}"
else
    echo -e "${YELLOW}i Standard Desktop/PC detected.${NC}"
fi

# Find the first USB Audio card index
MIC_CARD=$(arecord -l | grep -i "usb" | head -n1 | cut -d' ' -f2 | tr -d ':')

if [ -z "$MIC_CARD" ]; then
    echo -e "${RED}${BOLD}ERROR: No USB Microphone detected via 'arecord -l'.${NC}"
    echo -e "Please plug in your USB mic and restart this script."
    exit 1
fi
echo -e "${GREEN}✔ USB Microphone found on Card $MIC_CARD.${NC}"

# --- 2. Dependencies ---
print_section "Installing Core Dependencies..."
sudo apt update && sudo apt install -y sox libsox-fmt-all python3-venv python3-pip unzip curl alsa-utils wget jq

# --- 3. PulseAudio Strategy (Adaptive) ---
print_section "Audio Server Management"
if [ "$IS_PI" = true ]; then
    echo -e "Disabling PulseAudio (Recommended for Headless Pi)..."
    systemctl --user stop pulseaudio.service 2>/dev/null
    systemctl --user disable pulseaudio.service 2>/dev/null
    systemctl --user mask pulseaudio.service 2>/dev/null
    echo -e "${GREEN}✔ PulseAudio masked to prevent hardware locking.${NC}"
else
    echo -e "${RED}${BOLD}!!! DESKTOP WARNING !!!${NC}"
    echo -e "Masking PulseAudio on a Desktop will break volume keys and system sounds."
    echo -e "Recommendation: Keep PA alive and set the Mic profile to 'Off' in your Sound Settings."
    read -p "Do you still want to FORCE MASK PulseAudio? (y/n) > " FORCE_MASK
    if [[ "$FORCE_MASK" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        systemctl --user mask pulseaudio.service 2>/dev/null
        echo -e "${RED}✔ PulseAudio masked.${NC}"
    else
        echo -e "${GREEN}✔ PulseAudio kept alive.${NC}"
    fi
fi

# --- 4. Optional sispmctl Setup ---
echo -e "\n${MAGENTA}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${MAGENTA}│${NC} ${BOLD}HARDWARE SETUP:${NC} Install sispmctl for USB sockets?       ${MAGENTA}│${NC}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────┘${NC}"
read -p "  (y/n) > " INSTALL_SIS

if [[ "$INSTALL_SIS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    print_section "Configuring Energenie Hardware..."
    sudo apt install -y sispmctl
    sudo bash -c 'cat <<EOT > /etc/udev/rules.d/60-energenie.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="04b4", ATTR{idProduct}=="fd10", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="04b4", ATTR{idProduct}=="fd13", MODE="0666"
EOT'
    sudo udevadm control --reload-rules && sudo udevadm trigger
    echo -e "${GREEN}✔ sispmctl configured for non-root access.${NC}"
else
    echo -e "${YELLOW}i Skipping sispmctl installation.${NC}"
fi

# --- 5. Language & Model Selection (Vosk Small Models) ---
echo -e "\n${YELLOW}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│${NC} ${BOLD}SELECT VOSK MODEL (Optimized for Raspberry Pi):      ${YELLOW}│${NC}"
echo -e "${YELLOW}├──────────────────────────────────────────────────────────┤${NC}"
echo -e "${YELLOW}│${NC} 1) English (US)    - small-en-us-0.15                ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 2) Russian         - small-ru-0.22                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 3) German          - small-de-0.15                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 4) French          - small-fr-0.22                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 5) Spanish         - small-es-0.42                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 6) Portuguese      - small-pt-0.3                    ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 7) Chinese         - small-cn-0.22                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 8) Italian         - small-it-0.22                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 9) Japanese        - small-ja-0.22                   ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC} 10) Hindi          - small-hi-0.22                  ${YELLOW}│${NC}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────┘${NC}"
read -p "  Selection [1-10] > " LANG_CHOICE

case $LANG_CHOICE in
    1) M_NAME="vosk-model-small-en-us-0.15" ;;
    2) M_NAME="vosk-model-small-ru-0.22" ;;
    3) M_NAME="vosk-model-small-de-0.15" ;;
    4) M_NAME="vosk-model-small-fr-0.22" ;;
    5) M_NAME="vosk-model-small-es-0.42" ;;
    6) M_NAME="vosk-model-small-pt-0.3" ;;
    7) M_NAME="vosk-model-small-cn-0.22" ;;
    8) M_NAME="vosk-model-small-it-0.22" ;;
    9) M_NAME="vosk-model-small-ja-0.22" ;;
    10) M_NAME="vosk-model-small-hi-0.22" ;;
    *) M_NAME="vosk-model-small-en-us-0.15" ;;
esac

M_URL="https://alphacephei.com/vosk/models/${M_NAME}.zip"

if [ ! -d "$M_NAME" ]; then
    print_section "Downloading AI Model: $M_NAME..."
    wget -q --show-progress "$M_URL" -O model.zip
    unzip -q model.zip && rm model.zip
    echo "$M_NAME" > .active_model
    echo -e "${GREEN}✔ Model installed.${NC}"
else
    echo -e "${GREEN}✔ Model folder already exists.${NC}"
    echo "$M_NAME" > .active_model
fi

# --- 6. Calibration ---
print_section "Environment Noise Profiling"
echo -e "${RED}${BOLD}!!! STAY SILENT !!!${NC} Recording background noise in 3... 2... 1..."
# Use plughw to handle hardware card detection and sample rate conversion
arecord -D "plughw:$MIC_CARD,0" -c 1 -r 16000 -f S16_LE -d 5 silence_sample.wav

if [ -f "silence_sample.wav" ]; then
    sox silence_sample.wav -n noiseprof noise.prof
    rm silence_sample.wav
    echo -e "${GREEN}✔ Noise profile 'noise.prof' generated.${NC}"
else
    echo -e "${RED}ERROR: Calibration failed. arecord could not open the device.${NC}"
fi

# --- 7. Vocabulary Init ---
if [ ! -f "data.json" ]; then
    echo '{"lux lucet": "echo Light On"}' > data.json
    echo -e "${YELLOW}i Generated default data.json.${NC}"
fi

# --- Final Instructions ---
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${GREEN}${BOLD}             SETUP SUCCESSFULLY COMPLETED!          ${NC}"
echo -e "${BLUE}====================================================${NC}"

echo -e "${BOLD}1. CONFIGURATION:${NC}"
echo -e "   Edit ${YELLOW}data.json${NC} to map phrases to shell commands."
echo -e "   The AI only listens for phrases listed in your JSON keys."

echo -e "\n${BOLD}2. PREVENTING FALSE TRIGGERS:${NC}"
echo -e "   • Use ${MAGENTA}3+ syllable phrases${NC} (e.g., 'Activate System')."
echo -e "   • Run ${YELLOW}alsamixer${NC}, press F6, and set 'Capture' to ~60%."
echo -e "   • Ensure phrases in ${YELLOW}data.json${NC} are all lowercase."

echo -e "\n${BOLD}3. START THE ENGINE:${NC}"
echo -e "   Run: ${CYAN}node run.js${NC}"
echo -e "   View Logs: ${CYAN}journalctl -u voice-control.service -f${NC}"
echo -e "${BLUE}====================================================${NC}\n"
