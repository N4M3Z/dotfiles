# PdfCraft preferences

Chezmoi keeps the PdfCraft update check at start off in `~/Library/Application Support/PdfCraft/app.ron`.
PdfCraft then makes no network request at start.
Help ▸ Check for updates still works.

The source is `Library/Application Support/PdfCraft/modify_app.ron`, a Chezmoi modify template.
The live file arrives as `.chezmoi.stdin`, and the output becomes the new file.

PdfCraft stores the file as an eframe RON map.
The `pdfcraft` entry holds all preferences as one compact JSON object in a RON string.
In that string, the preference is always the text `\"update_check_at_start\":true` or `\"update_check_at_start\":false`.
The template replaces the first form with the second form.
It does not parse the file, so the recent files, the trusted certificates, and the layout stay byte for byte.

An absent or empty file starts with the managed preference only.
A file without the preference makes the apply stop, and Chezmoi does not change the file.
Start and quit PdfCraft one time to write the preference, then apply again.

PdfCraft picks millimetres on first start for every region outside the United States, Liberia, and Myanmar.
The units do not need management.
The trusted certificate list holds a personal certificate, so this public repository does not track it.

## Reconcile GUI changes

PdfCraft writes the file when it quits.
If you turn the check on in the Preferences dialog, the next apply turns it off again.

1. Quit PdfCraft.
2. Inspect the target with `chezmoi diff ~/Library/Application\ Support/PdfCraft/app.ron`.
3. Apply the target with `chezmoi apply ~/Library/Application\ Support/PdfCraft/app.ron`.

Run `bash tests/test-pdfcraft-config.sh` to test the template against a temporary destination.
The test does not change the live PdfCraft file.
