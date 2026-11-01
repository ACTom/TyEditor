# Plugin package and protocol v1

TyEditor v1 plugins are distributed as **`.typlugin` packages**. A package is a
ZIP archive with `plugin.json` at its root. The host discovers packages installed
in the user plugin directory and development plugins in a directory tree; bundled
samples are ordinary directories under `data/plugins/`.

The implementation is split across:

| Unit | Responsibility |
| --- | --- |
| `src/plugins/upluginapi.pas` | Manifest model, compatibility checks, locales, manifest parser |
| `src/plugins/upluginruntime.pas` | Process and PascalScript runtimes, shared request/response boundary |
| `src/plugins/upluginhost.pas` | Discovery, user-override precedence, execution dispatch |
| `src/plugins/upluginmanager.pas` | `.typlugin` install/uninstall, enable state, `plugins.json` |
| `src/ui/upluginmanagerdlg.pas` | **Plugins > Manage Plugins...** |
| `src/ui/upluginoptionsdlg.pas` | Per-command option dialog |
| `src/ui/upluginrun.pas` | Background execution and cancellation |

## Package layout

```text
example.typlugin (ZIP)
├── plugin.json
├── locales/
│   ├── en.json
│   └── zh_CN.json
├── plugin.py                 # process runtime
├── main.ps                   # PascalScript runtime
├── LICENSE
└── assets/...
```

The archive root must contain `plugin.json`. Absolute paths, `..` path segments,
drive-qualified names and symbolic links are rejected during installation.
A package may omit `locales/`; manifest text is then used as the fallback.

## Discovery and precedence

The host scans:

1. bundled: `data/plugins/` next to the executable (or
   `Contents/Resources/data/plugins/` in the macOS bundle);
2. user: `<configuration>/plugins/`.

A user plugin with the same `id` as a bundled plugin overrides the bundled one.
The manager shows both sources and reports invalid manifests through
**Plugins > Plugin Errors**. State is stored in `<configuration>/plugins.json`:

```json
{"disabled": ["example.plugin"]}
```

A plugin that fails compatibility remains visible in the manager but is disabled
with a reason. Bundled plugins cannot be uninstalled. Installing a package with
the same `id` replaces the user copy only after the new package has been
validated and extracted.

## Manifest

```json
{
  "schema": 1,
  "api": 1,
  "id": "example.upper",
  "name": "Uppercase",
  "version": "1.0.0",
  "description": "Uppercase the selection.",
  "publisher": "Example",
  "license": "MIT",
  "homepage": "https://example.invalid",
  "default_locale": "en",
  "timeout_ms": 5000,
  "compatibility": {
    "editor": ">=0.1.0 <2.0.0",
    "platforms": ["any"]
  },
  "runtime": {
    "type": "process",
    "command": ["python3", "${pluginDir}/plugin.py"]
  },
  "permissions": ["text.read", "text.write"],
  "commands": [
    {"id": "upper", "title": "Uppercase Selection", "scope": "selection"}
  ],
  "options": []
}
```

Required fields: `schema`, `api`, `id`, `name`, `version`, `runtime` and at least
one valid `commands` entry. `schema` and `api` must both be `1` in this release.
`id` must be stable and must not contain path separators or drive colons. `version` is a dotted
version string; `editor` compatibility uses the same comparison rules as
`scripts/dev/version.py`.

### Runtime

Process runtime:

```json
"runtime": {
  "type": "process",
  "command": ["python3", "${pluginDir}/plugin.py"]
}
```

`command` is an array. The first item is the executable; the remaining items are
arguments. A bare executable is looked up on `PATH`; a relative executable is
resolved against the package directory. The host does not invoke a shell.
`${pluginDir}` expands to the package directory and `${platform}` expands to the
current platform ID (`linux-x86_64`, `win64-x86_64`, etc.).

PascalScript runtime:

```json
"runtime": {
  "type": "pascalscript",
  "entry": "main.ps"
}
```

The entry file is a complete PascalScript program, traditionally ending in
`begin ... end.`. It runs in the restricted script engine and only sees the API
functions listed below. The `symbol` field is reserved for future named-entry
support.

Optional fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `description` | empty | Short description; shown in the manager |
| `publisher`, `license`, `homepage` | empty | Display/bundle metadata |
| `default_locale` | `en` | Locale used when no translation matches |
| `timeout_ms` | `10000` | Process timeout; clamped to at least `1000` |
| `compatibility.editor` | no constraint | Version constraint, e.g. `>=0.1.0 <2.0.0` |
| `compatibility.platforms` | all | `any` or IDs such as `linux-x86_64`, `win64-x86_64`, `darwin-aarch64` |
| `permissions` | empty | Advisory capability list: `text.read`, `text.write`, `process.spawn` |

### Commands and options

A command has a stable `id`, a default `title`, and a `scope`:

| Scope | Editor behavior |
| --- | --- |
| `selection` | Requires a non-empty selection; `selection.text` is the action text |
| `document` | Sends the full document as `context.text` |
| `none` | Does not require text |

Options are plugin-wide and are shown before each command invocation:

```json
"options": [
  {
    "id": "indent",
    "type": "choice",
    "label": "Indentation",
    "default": "2",
    "choices": [
      {"value": "2", "label": "2 spaces"},
      {"value": "4", "label": "4 spaces"}
    ]
  },
  {"id": "sort_keys", "type": "bool", "label": "Sort object keys", "default": "false"}
]
```

Supported `type` values are `choice`, `string` and `bool`. All option values are
sent as strings in `options`; booleans are `"true"` or `"false"`.

## Process request

The host writes one UTF-8 JSON object followed by a newline to stdin:

```json
{
  "api": 1,
  "protocol": 1,
  "plugin": "example.upper",
  "command": "upper",
  "scope": "selection",
  "options": {"indent": "2"},
  "context": {
    "locale": "zh_CN",
    "file": "/home/user/notes.txt",
    "encoding": "UTF-8",
    "eol": "LF",
    "lexer": "Python",
    "modified": false,
    "text": "hello",
    "selection": {
      "text": "hello",
      "start": 0,
      "end": 5,
      "length": 5,
      "caret_x": 5,
      "caret_y": 0
    },
    "carets": [{"offset": 5}]
  }
}
```

The full document is always present as `context.text`; `context.selection.text`
is the selected text. Offsets are editor-native string offsets, not byte offsets.
`context.locale` is the editor’s effective UI locale and is the locale plugins
should use for their own messages.

Process plugins must write exactly one JSON object to stdout. Diagnostics belong
on stderr. stderr is captured and included in errors when stdout is missing or
malformed. The process is terminated on timeout or cancellation.

## Response

```json
{
  "api": 1,
  "ok": true,
  "actions": [
    {"type": "replace_selection", "text": "HELLO"}
  ],
  "message_key": "status.done",
  "message": "Done"
}
```

`message_key` is resolved against the plugin’s locale files; `message` is the
fallback. An action can also provide `message_key` and `message`.

Supported action types:

| `type` | Fields | Effect |
| --- | --- | --- |
| `replace_selection` | `text` | Replace the selection |
| `replace_document` | `text` | Replace the whole document and mark it modified |
| `insert_text` | `text` | Insert at the caret |
| `set_caret` | `line`, `col` | Move the caret (zero-based editor coordinates) |
| `message` | `text` or `message_key` | Show a modal message |
| `log` | `text` | Write a diagnostic line to stdout/log |

For backward compatibility the host also accepts `kind` instead of `type` and
legacy top-level fields where documented in older sample notes. New plugins
should use `type`. Unknown actions are ignored. When `ok` is false, the host
shows the localized `message_key`/`message` instead of applying actions.

## Localization

Each package owns its translations under `locales/<locale>.json`. Stable IDs are
never translated. Use these keys:

| Key | Meaning |
| --- | --- |
| `plugin.name` | Plugin display name |
| `plugin.description` | Description |
| `command.<id>.title` | Command title |
| `option.<id>.label` | Option label |
| `option.<id>.choice.<value>` | Choice label |
| arbitrary keys | Resolve with `message_key` |

Resolution order is exact locale, base language (`zh` for `zh_CN`), the manifest
`default_locale`, `en`, then the fallback string supplied by the host or
manifest. A partial translation is valid. Application strings use TyEditor’s own
translation files and must not be copied into plugin packages.

## PascalScript API

Scripts can call:

```pascal
function GetText: string;                              // full document
function GetSelection: string;                         // selected text
function GetOption(Name: string): string;              // current option value
function GetLocale: string;                            // context.locale
function GetFileName: string;                          // context.file
procedure ReplaceSelection(Value: string);
procedure ReplaceDocument(Value: string);
procedure InsertText(Value: string);
procedure SetCaret(Line, Col: Integer);
procedure Message(Value: string);
procedure Log(Value: string);
```

Example `main.ps`:

```pascal
begin
  ReplaceSelection(GetSelection + ':' + GetOption('suffix'));
  Message('script-ok');
end.
```

PascalScript is restricted to the registered API; it has no filesystem, network,
process or editor-object access. It runs off the UI thread and is stopped when
the user cancels the progress dialog.

## Python example

```python
import json
import sys

request = json.load(sys.stdin)
context = request.get("context", {})
text = context.get("selection", {}).get("text", "")
response = {
    "api": 1,
    "ok": True,
    "actions": [{"type": "replace_selection", "text": text.upper()}],
    "message_key": "status.done",
}
json.dump(response, sys.stdout, ensure_ascii=False)
sys.stdout.write("\n")
```

## Security and signing

v1 does not require package signatures, but manifests reserve `sha256` and
`signature` for a future release. User plugins are untrusted: the first execution
in a session asks for confirmation. Plugins inherit the user’s permissions. The
host uses a timeout, captures stderr and runs work in a background thread with a
cancel button. Only install packages from sources you trust until signing is
implemented.

## Packaging

Use the repository script to produce an installable archive:

```bash
./scripts/dev/package-plugin.py data/plugins/base64
# -> dist/plugins/sample.base64-1.0.0.typlugin
```

`./scripts/dev/package-plugins.sh` packages every bundled sample. The archive
contains the manifest, locales and scripts at its root; TyEditor’s manager
validates and extracts it into the user plugin directory.
