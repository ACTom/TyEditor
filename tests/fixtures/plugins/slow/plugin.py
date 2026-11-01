import json
import sys
import time

time.sleep(3)
json.dump({"api": 1, "ok": True, "actions": []}, sys.stdout)
