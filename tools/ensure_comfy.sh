#!/usr/bin/env bash
# Make sure ComfyUI is up. It gets OOM-killed while other jobs hold RAM
# (video renders, Godot editor, browsers), so generation scripts call this
# before each run and it restarts the server if the port is dead.
set -u
PORT=8188
if curl -s -m 3 -o /dev/null "http://127.0.0.1:${PORT}/system_stats"; then
  exit 0
fi
pkill -f "/home/g1/ComfyUI/main.py" 2>/dev/null || true
sleep 2
cd /home/g1/ComfyUI || exit 1
setsid .venv/bin/python main.py --listen 0.0.0.0 --port "$PORT" --lowvram \
  > /tmp/opencode/comfyui.log 2>&1 & disown
for _ in $(seq 1 60); do
  sleep 2
  if curl -s -m 3 -o /dev/null "http://127.0.0.1:${PORT}/system_stats"; then
    echo "comfyui up"
    exit 0
  fi
done
echo "comfyui failed to start" >&2
exit 1
