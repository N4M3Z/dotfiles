# OpenLogi preferences

Chezmoi manages selected preferences in `~/.config/openlogi/config.toml`.
The source is `dot_config/openlogi/modify_private_config.toml`.
It uses a [native Chezmoi modify template](https://www.chezmoi.io/user-guide/manage-different-types-of-file/).
The source has no `.tmpl` extension.

The template manages these preferences:

- Login launch, update checks, and automatic update installation.
- Menu bar visibility and mouse event capture.
- Smooth scrolling, vertical scroll sensitivity, and thumbwheel sensitivity.
- App icon, asset downloads, and asset source.
- Appearance, interface scale, and device view mode.

The template preserves all other keys, including `update_prompt_seen`, device records, keyboard settings, and the selected device.
It preserves the existing schema version.
An absent or empty file starts with schema version 7, as used by OpenLogi 0.8.6.
Malformed TOML stops the operation without replacing the file.
An invalid `app_settings` value also stops the operation.
The `private_` attribute sets the target mode to `0600`.
TOML serialization can change formatting and remove comments.

Do not track device identities, discovery records, backups, lock files, or `overlay.claim`.
The two OpenLogi preference plists currently contain only a macOS framework setting.
They do not need management.

## Reconcile GUI changes

The OpenLogi GUI can change this file.
The next Chezmoi apply restores managed preference values from the source.
Unmanaged values remain local.

1. Review the GUI changes that you want to keep.
2. Edit the corresponding values in the source template.
3. Stop OpenLogi and its background components before you apply changes.
4. Inspect the target with `chezmoi diff ~/.config/openlogi/config.toml`.
5. Apply the target with `chezmoi apply ~/.config/openlogi/config.toml`.
6. Restart OpenLogi and check the preferences in the GUI.

Do not replace the template with a complete copy of the live configuration.
Run `python3 tests/test-openlogi-config.py` to test temporary destinations.
The tests need Chezmoi and Python 3.11 or later.
They do not change the live OpenLogi configuration.
