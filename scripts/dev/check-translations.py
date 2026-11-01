#!/usr/bin/env python3
import glob, json, os, re, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
keys = set()
for path in glob.glob(root + '/src/**/*.pas', recursive=True):
    text = open(path, encoding='utf-8').read()
    keys.update(m.group(1) for m in re.finditer(r"Tr\('([^']*)'\)", text))
    for fn in ('AddItem', 'AddSub', 'AddLabel', 'AddCheck'):
        keys.update(m.group(1) for m in re.finditer(r"\b" + fn + r"\([^\n]*?'([^']*)'", text) if m.group(1) != '-')
data = json.load(open(root + '/languages/tyeditor.zh_CN.json', encoding='utf-8'))
missing = sorted(k for k in keys if k not in data)
if missing:
    print('Missing translations (%d):' % len(missing))
    print('\n'.join(missing))
    sys.exit(1)
print('Translations complete: %d app strings' % len(keys))
