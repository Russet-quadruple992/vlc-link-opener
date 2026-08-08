import sys
import json
import struct
import subprocess
import os
import logging

# Setup logging to diagnose any runtime issues
log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vlc_host.log")
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

logging.info("VLC Host started.")

def read_message():
    try:
        # Read the message length (first 4 bytes)
        raw_length = sys.stdin.buffer.read(4)
        if len(raw_length) == 0:
            logging.info("Stdin EOF reached (disconnected).")
            sys.exit(0)
        message_length = struct.unpack('@I', raw_length)[0]
        logging.info(f"Incoming message length: {message_length} bytes.")
        
        # Read the message body
        message_bytes = sys.stdin.buffer.read(message_length)
        if len(message_bytes) < message_length:
            logging.error("Incomplete message body read.")
            sys.exit(1)
            
        message = message_bytes.decode('utf-8')
        logging.info(f"Received raw message: {message}")
        return json.loads(message)
    except Exception as e:
        logging.exception("Error reading message:")
        sys.exit(1)

def send_message(message_dict):
    try:
        message_bytes = json.dumps(message_dict).encode('utf-8')
        length_bytes = struct.pack('@I', len(message_bytes))
        sys.stdout.buffer.write(length_bytes)
        sys.stdout.buffer.write(message_bytes)
        sys.stdout.buffer.flush()
        logging.info(f"Sent response: {message_dict}")
    except Exception as e:
        logging.exception("Error sending message:")

def find_vlc():
    # Standard installation paths for VLC on Windows
    paths = [
        os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "VideoLAN", "VLC", "vlc.exe"),
        os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "VideoLAN", "VLC", "vlc.exe"),
    ]
    for p in paths:
        if os.path.exists(p):
            logging.info(f"Found VLC at: {p}")
            return p
    logging.warning("VLC not found in standard paths. Attempting to run via command 'vlc'...")
    return "vlc" # Fallback to system PATH

def main():
    try:
        msg = read_message()
        if msg.get("ping"):
            logging.info("Ping message received.")
            send_message({"status": "ok", "ping": True})
            return

        url = msg.get("url")
        if not url:
            logging.warning("No URL provided in message.")
            send_message({"status": "error", "error": "No URL provided"})
            return
        
        vlc_bin = find_vlc()
        logging.info(f"Launching VLC for URL: {url}")
        
        # Launch VLC asynchronously
        logging.info("Attempting to launch VLC...")
        pid = None
        launched = False
        
        if os.name == 'nt':
            # Method 1: Try os.startfile (supported in Python 3.10+) which escapes Chrome's job sandbox completely
            try:
                os.startfile(vlc_bin, arguments=f'"{url}"')
                logging.info("VLC successfully launched via os.startfile.")
                launched = True
            except (TypeError, AttributeError):
                logging.warning("os.startfile with arguments is not supported in this Python version. Trying cmd start...")
            except Exception as e:
                logging.warning(f"os.startfile failed: {e}. Trying cmd start...")
                
            # Method 2: Fallback to cmd.exe's 'start' command which also escapes Chrome's sandbox and ensures GUI visibility
            if not launched:
                try:
                    cmd = f'start "" "{vlc_bin}" "{url}"'
                    subprocess.Popen(cmd, shell=True)
                    logging.info("VLC successfully launched via cmd start command.")
                    launched = True
                except Exception as e:
                    logging.warning(f"cmd start command failed: {e}. Falling back to default Popen...")
                    
        # Method 3: Default subprocess.Popen as final fallback
        if not launched:
            proc = subprocess.Popen(
                [vlc_bin, url],
                close_fds=True
            )
            pid = proc.pid
            logging.info(f"VLC process spawned via Popen with PID {pid}.")
            
        send_message({"status": "success", "pid": pid})
        
    except Exception as e:
        logging.exception("Error in main loop:")
        send_message({"status": "error", "error": str(e)})

if __name__ == '__main__':
    main()
