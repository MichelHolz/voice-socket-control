const { spawn, execSync, exec } = require('child_process');
const path = require('path');
const fs = require('fs');

// --- Logging Helper ---
const log = (msg, type = 'INFO') => {
    const timestamp = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '');
    const colors = { INFO: '\x1b[36m', SUCCESS: '\x1b[32m', WARN: '\x1b[33m', ERROR: '\x1b[31m' };
    console.log(`${timestamp} [${colors[type] || ''}${type}\x1b[0m] ${msg}`);
};

const PYTHON_VENV = path.join(__dirname, 'venv/bin/python3');
const LISTENER_SCRIPT = path.join(__dirname, 'listener.py');
const CONFIG_FILE = path.join(__dirname, 'data.json');

log("Initializing Voice Control System...");

// Auto-detect Mic Card
let MIC_DEVICE;
try {
    const MIC_CARD = execSync("arecord -l | grep -i 'usb' | head -n1 | cut -d' ' -f2 | tr -d ':'").toString().trim();
    MIC_DEVICE = `plughw:${MIC_CARD},0`;
    log(`Hardware Detected: Using ${MIC_DEVICE}`, "SUCCESS");
} catch (e) {
    log("No USB Microphone found! Ensure it is plugged in.", "ERROR");
    process.exit(1);
}

const keywordMap = JSON.parse(fs.readFileSync(CONFIG_FILE));
log(`Loaded ${Object.keys(keywordMap).length} phrases from data.json`);

// --- Processes ---
const recorder = spawn('arecord', [
    '-D', MIC_DEVICE, '-c', '1', '-r', '16000', '-f', 'S16_LE', '-t', 'raw', '--buffer-size=1000'
]);

const pythonWorker = spawn(PYTHON_VENV, [LISTENER_SCRIPT]);

recorder.stdout.pipe(pythonWorker.stdin);

// Handle AI Output
pythonWorker.stdout.on('data', (data) => {
    const output = data.toString('utf8').trim();    
    
    if (output === "LISTENER_READY") {
        log("AI Engine is live and listening...", "SUCCESS");
    } else if (output.startsWith("TEXT_RECOGNIZED:")) {
        const phrase = output.replace("TEXT_RECOGNIZED:", "").trim();
        log(`Recognized phrase: "${phrase}"`, "INFO");

        if (keywordMap[phrase]) {
            log(`Executing CMD: ${keywordMap[phrase]}`, "SUCCESS");
            exec(keywordMap[phrase], (error) => {
                if (error) log(`Command Failed: ${error.message}`, "ERROR");
            });
        } else {
            log(`Phrase "${phrase}" has no mapping in data.json`, "WARN");
        }
    }
});

// Handle Python Errors
pythonWorker.stderr.on('data', (data) => {
    log(`Vosk Internal: ${data.toString().trim()}`, "WARN");
});

process.on('SIGINT', () => {
    log("Shutting down processes...", "WARN");
    recorder.kill();
    pythonWorker.kill();
    process.exit();
});
