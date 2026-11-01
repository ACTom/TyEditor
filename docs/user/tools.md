# External tools

External tools are user-configured commands that work on the current document.
They are deliberately separate from plugins: a tool is not a package, is not
installed from a `.typlugin` file, and never appears in the plugin manager.

A tool receives text on standard input and returns text on standard output. It
can also read the current file directly through placeholders such as `${file}`.

## Managing tools

Open **Tools > Manage Tools...** to:

- Create, edit and delete tools.
- Enable or disable a tool; disabled tools are hidden from the Tools menu.
- Reorder tools with **Move Up** / **Move Down**; the menu follows the list
  order.

**Tools > Reload Tools** re-reads the configuration file, for example after
editing it by hand.

Tools are stored in `tools.json` in the configuration directory:

| Platform | File |
| --- | --- |
| Linux | `~/.config/TyEditor/tools.json` |
| Windows | `%APPDATA%\TyEditor\tools.json` |
| macOS | `~/Library/Application Support/TyEditor/tools.json` |

The file is written atomically. Invalid entries are skipped and reported under
**Tools > Tool Errors**.

## Tool options

| Field | Meaning |
| --- | --- |
| Name | Caption used in the Tools menu |
| Command | Executable name (found through `PATH`), absolute path, or path relative to the working folder |
| Arguments | One argument per line; blank lines are ignored |
| Working folder | Process working directory; empty means the document's folder |
| Input | `None`, `Selection` or `Document` |
| Output | `Ignore`, `Show in a window`, `Insert at caret`, `Replace selection` or `Replace document` |
| Save before | `Never`, `Current file` or `All files` |
| Timeout | Seconds, 1–600 (stored as milliseconds) |
| Enabled | Whether the tool appears in the Tools menu |

Commands never go through a shell. Each line under **Arguments** is passed to
the process as exactly one argument, including spaces and quotes; there is no
globbing, variable expansion or pipe syntax.

Text is exchanged as UTF-8: standard input, `${inputfile}` and standard output
are UTF-8 regardless of the document's saved encoding. `${encoding}` reports the
document's actual encoding so a tool can convert if it needs to.

Input modes:

- **None** — standard input is closed immediately. Use this for commands that
  only need `${file}` or no document at all.
- **Selection** — the selection is sent to standard input. The tool refuses to
  run when nothing is selected.
- **Document** — the whole buffer is sent to standard input.

Output modes:

- **Ignore** — the command runs for its side effects only.
- **Show in a window** — a read-only, scrollable window shows standard output
  and, when present, standard error.
- **Insert at caret** — output is inserted at the caret.
- **Replace selection** — output replaces the selection (or is inserted when
  there is no selection).
- **Replace document** — output replaces the whole buffer and marks it
  modified.

## Placeholders

Placeholders are expanded in the command, working folder and every argument.

| Placeholder | Expands to |
| --- | --- |
| `${file}` | Full path of the current file (empty for an untitled tab) |
| `${filename}` | File name without directory |
| `${dir}` | Directory containing the file |
| `${line}` | Caret line, 1-based |
| `${col}` | Caret column, 1-based |
| `${lexer}` | Current syntax lexer name |
| `${encoding}` | Current encoding name |
| `${eol}` | Line-ending style (`CRLF`, `LF`, `CR`) |
| `${inputfile}` | Path to a temporary file containing the tool input |
| `${/}` | Platform path separator |

`${inputfile}` is only created when it is referenced. When it is used, the input
text is written to that temporary file and standard input is left closed, so a
command that requires a file path can be used directly. The file is removed
after the run.

## Examples

**Format the document with clang-format**

- Command: `clang-format`
- Arguments: `-style=file`
- Input: `Document`
- Output: `Replace document`
- Save before: `Current file`

`clang-format` reads standard input and writes the formatted text to standard
output.

**Sort the selected lines**

- Command: `sort`
- Input: `Selection`
- Output: `Replace selection`

**Count words in the selection**

- Command: `wc`
- Arguments: `-w`
- Input: `Selection`
- Output: `Show in a window`

**Open the current file in another program**

- Command: `xdg-open` (Linux) or `explorer.exe` (Windows)
- Arguments: `${file}`
- Input: `None`
- Output: `Ignore`
- Save before: `Current file`

**Show the git diff for the current file**

- Command: `git`
- Arguments: `diff`, `--no-color`, `--`, `${file}`
- Working folder: `${dir}`
- Input: `None`
- Output: `Show in a window`
- Save before: `Current file`

## Execution and errors

Tools run in a background thread. The progress dialog offers **Cancel**, and the
process is terminated when the timeout expires. A non-zero exit code is treated
as a failure: the error dialog includes the exit code and a truncated standard
error message.

Tools run with the same privileges as TyEditor. Only add commands you trust.

## Current limits

- Tools have no custom keyboard shortcuts.
- There is no import/export for tool definitions; edit `tools.json` to copy
  them between machines.
- Tools cannot modify the document when the document has no tab (for example
  when launched without files); use **Show in a window** for global commands.
