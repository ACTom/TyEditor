import json
import sys

json.load(sys.stdin)
json.dump({"api": 1, "ok": True, "actions": []}, sys.stdout)
