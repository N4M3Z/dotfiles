# PdfCraft preferences

Chezmoi manages selected PdfCraft preferences in `~/Library/Application Support/PdfCraft/app.ron`.
The source is `Library/Application Support/PdfCraft/modify_app.ron.tmpl`.
It is a modify script: the live file arrives on stdin, and the output becomes the new file.

PdfCraft stores the file as an eframe RON map.
The `pdfcraft` entry holds all preferences as one JSON object in a RON string.
The `egui` and `window` entries hold the layout and the window position.
Chezmoi has no RON parser, so the script runs Python 3 to read the RON string and the JSON object.

The script manages one preference:

- `update_check_at_start` is false. PdfCraft then makes no network request at start.
  Help ▸ Check for updates still works.

The script keeps all other preferences, the recent files, the trusted certificates, and the layout.
When the managed values already match, the output is the input, byte for byte.
When the script changes a value, it writes the JSON object again with sorted keys.
It writes each character as itself, so an escape such as `\u{301}` becomes the accent character.
PdfCraft reads both forms.

PdfCraft ignores a preferences object that does not parse, and then starts from its defaults.
For this reason, the script stops on any text that it cannot read, and Chezmoi does not change the file.
An absent or empty file starts with the managed preferences only.
PdfCraft reads each preference only when its key is present, so the other preferences keep their defaults.

PdfCraft picks millimetres on first start for every region outside the United States, Liberia, and Myanmar.
The units do not need management.
The trusted certificate list holds a personal certificate, so this public repository does not track it.

## Reconcile GUI changes

PdfCraft writes the file when it quits.
A value that you change in the Preferences dialog stays local until the next apply.
The next apply restores the managed values.

1. Quit PdfCraft.
2. Edit `MANAGED` in the source script to keep a new value.
3. Inspect the target with `chezmoi diff ~/Library/Application\ Support/PdfCraft/app.ron`.
4. Apply the target with `chezmoi apply ~/Library/Application\ Support/PdfCraft/app.ron`.
5. Start PdfCraft and check the preference in the Preferences dialog.

Do not replace the script with a copy of the live file.
Run `python3 tests/test-pdfcraft-config.py` to test temporary destinations.
The tests need Chezmoi and Python 3.
They do not change the live PdfCraft file.
