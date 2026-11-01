# Plugins

TyEditor v1 plugins are distributed as **`.typlugin` packages**. A package is a
ZIP archive containing a `plugin.json` manifest, optional translations and the
plugin’s own scripts or executables.

Plugins never run through a shell. Work runs in the background with a cancel
button; process plugins also have a timeout and captured stderr. Each package
has its own identity, compatibility range, runtime, options and translations.

Plugins are separate from **external tools**. A plugin is an installed package
with a manifest; an external tool is a command you configure locally under
**Tools > Manage Tools...** and is never installed from a `.typlugin` file. See
[External tools](tools.md) for that feature.

## Bundled examples

The repository ships these sample plugins in `data/plugins/`:

| Plugin | Actions |
| --- | --- |
| Base64 Tools | Encode or decode the current selection as Base64 |
| Text Tools | Uppercase, lowercase, title case, trim trailing spaces |
| Caesar Cipher | Demo encryption/decryption of ASCII letters (shift 3) |
| JSON Formatter | Format or minify a JSON document, with indent/sort options |

The four samples use the embedded PascalScript runtime, so they run on every
supported platform without an external interpreter or package dependency. They
are examples, not required parts of the editor; remove them from a distribution
if they are undesirable.

To run an external formatter such as `clang-format`, configure it as an
[external tool](tools.md) under **Tools > Manage Tools...** instead of installing
a plugin.

Bundled plugins can be disabled but not uninstalled.

## Using plugins

1. Open the **Plugins** menu. Enabled plugins and their commands appear under
   their own submenus.
2. Select text if the command has `scope: "selection"`, then choose the command.
3. If the plugin declares options, a small dialog appears before execution.
4. For a user plugin, TyEditor asks for confirmation the first time it is run in
   a session.
5. Use **Plugins > Reload Plugins** after changing an unpacked development
   plugin, or **Manage Plugins...** for package installation and enable state.

A progress dialog appears while a plugin runs. **Cancel** asks the runtime to
stop; the UI remains responsive.

## Managing plugins

Choose **Plugins > Manage Plugins...**. The manager:

- lists bundled and user plugins, their versions and sources;
- enables or disables plugins; state is saved in `plugins.json`;
- installs a `.typlugin` package;
- uninstalls user plugins;
- reloads packages after a change;
- opens the user plugin directory;
- shows compatibility reasons and manifest errors.

An incompatible plugin remains visible but is disabled. A user plugin with the
same `id` as a bundled plugin takes precedence.

## Installing a package

Choose **Plugins > Install Plugin...** and select a `.typlugin` file. The
manager validates the archive, manifest and path safety, extracts it under the
user plugin directory and reloads it. A package that is incompatible with the
current editor version or platform is installed but remains disabled with the
reason shown in the manager.

The package must have `plugin.json` at its ZIP root:

```text
my-plugin.typlugin
├── plugin.json
├── locales/
│   ├── en.json
│   └── zh_CN.json
└── plugin.py
```

For development you can also keep an unpacked plugin directory under the user
plugin folder and use **Reload Plugins**. Do not manually copy a package into
the folder expecting it to load; use the installer so the archive is validated
and extracted.

User plugin directory:

| Platform | Location |
| --- | --- |
| Linux | `~/.config/TyEditor/plugins/` |
| Windows | `%APPDATA%\TyEditor\plugins\` |
| macOS | `~/Library/Application Support/TyEditor/plugins/` |

Bundled plugins are found under `data/plugins/` next to the executable (or in
`Contents/Resources/data/plugins/` in the macOS bundle).

## Manifest overview

A minimal package manifest:

```json
{
  "schema": 1,
  "api": 1,
  "id": "example.uppercase",
  "name": "Uppercase",
  "version": "1.0.0",
  "description": "Uppercase the current selection.",
  "default_locale": "en",
  "runtime": {
    "type": "pascalscript",
    "entry": "main.ps"
  },
  "timeout_ms": 5000,
  "compatibility": {
    "editor": ">=0.1.0 <2.0.0",
    "platforms": ["any"]
  },
  "permissions": ["text.read", "text.write"],
  "commands": [
    {
      "id": "upper",
      "title": "Uppercase Selection",
      "scope": "selection"
    }
  ],
  "options": []
}
```

Required fields are `schema`, `api`, `id`, `name`, `version`, `runtime` and at
least one command. `compatibility.platforms` accepts `any` or IDs such as
`linux-x86_64`, `win64-x86_64` and `darwin-aarch64`. A plugin that does not
support the current platform or editor version remains visible but disabled.

Process plugins declare a `command` array; `${pluginDir}` expands to the package
directory. The host does not invoke a shell.

PascalScript plugins declare:

```json
"runtime": {"type": "pascalscript", "entry": "main.ps"}
```

They run in the restricted embedded runtime and use the text API described in
the [plugin protocol](../dev/PLUGIN_PROTOCOL.md). v1 does not include a
JavaScript runtime or native dynamic-library plugins.

## Options and translations

Options are plugin-wide and appear before every command:

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

Place per-plugin translations under `locales/`:

```text
locales/en.json
locales/zh_CN.json
```

Example keys:

```json
{
  "plugin.name": "Uppercase",
  "plugin.description": "Uppercase the current selection.",
  "command.upper.title": "Uppercase Selection",
  "option.indent.label": "Indentation",
  "option.indent.choice.2": "2 spaces",
  "status.done": "Done"
}
```

Fallback order is exact locale, base language, manifest default locale, English,
then the manifest text. Partial translations are allowed. Plugin translations
are separate from TyEditor’s own UI translation files.

## Protocol and examples

The complete request/response reference, PascalScript API, compatibility rules,
security notes and packaging commands are in
[Plugin package and protocol v1](../dev/PLUGIN_PROTOCOL.md).

A minimal process plugin (Python):

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
}
json.dump(response, sys.stdout, ensure_ascii=False)
sys.stdout.write("\n")
```

Write stdout as one JSON object and send diagnostics to stderr. The host reports
malformed JSON, missing responses, timeouts, cancellation and stderr in an error
dialog.

## Security

Bundled plugins are treated as trusted. User plugins require confirmation before
their first execution in each session. Plugins run with the same user
permissions as TyEditor, so only install packages whose source you trust.
v1 does not require package signatures; `sha256`/`signature` manifest fields are
reserved for a later release.

## Limitations

- One plugin invocation per command; there is no long-lived plugin process.
- The host passes the editor environment; plugin-specific environment values are
  not configurable in v1.
- Runtimes are `process` and `pascalscript`; JavaScript and native libraries are
  planned, not available in v1.
- Plugin strings are not merged into the application translation files.
