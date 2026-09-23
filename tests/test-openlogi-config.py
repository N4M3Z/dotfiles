#!/usr/bin/env python3
"""Test OpenLogi preferences with Chezmoi in temporary directories."""

import pathlib
import shutil
import stat
import subprocess
import tempfile
import tomllib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = pathlib.Path("dot_config/openlogi/modify_private_config.toml")
PREFERENCES = {
    "launch_at_login": True,
    "check_for_updates": True,
    "auto_install_updates": False,
    "show_in_menu_bar": True,
    "capture_mouse_events": True,
    "smooth_scroll": False,
    "vertical_scroll_sensitivity": 14,
    "app_icon": "openlogi",
    "auto_download_assets": True,
    "asset_source": "automatic",
    "thumbwheel_sensitivity": 14,
    "appearance": "system",
    "ui_scale": "normal",
    "device_view_mode": "grid",
}


class OpenLogiConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="openlogi-chezmoi-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        self.target = self.destination / ".config/openlogi/config.toml"
        source_file = self.source / SOURCE_FILE
        source_file.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / SOURCE_FILE, source_file)
        self.target.parent.mkdir(parents=True)
        config = self.root / "chezmoi.toml"
        config.write_text("")
        self.command = [
            "chezmoi",
            "--source", str(self.source),
            "--destination", str(self.destination),
            "--config", str(config),
            "--persistent-state", str(self.root / "state.boltdb"),
            "--cache", str(self.root / "cache"),
            "--no-tty",
            "--force",
        ]

    def run_chezmoi(self, command, *, succeeds=True):
        result = subprocess.run(
            [*self.command, command, str(self.target)],
            text=True,
            capture_output=True,
            check=False,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def read_config(self):
        return tomllib.loads(self.target.read_text())

    def test_render_and_apply_preserve_unmanaged_values(self):
        original = """schema_version = 42
selected_device = "local-selection"
future_value = "keep"

[app_settings]
appearance = "dark"
vertical_scroll_sensitivity = 3
update_prompt_seen = true
future_preference = "keep"

[app_settings.future_table]
enabled = true

[devices]
local_metadata = { name = "test device", discovered = true }

[keyboard]
local_choice = "keep"
"""
        self.target.write_text(original)
        self.target.chmod(0o644)
        rendered = tomllib.loads(self.run_chezmoi("cat").stdout)
        self.assertEqual(self.target.read_text(), original)
        expected = tomllib.loads(original)
        expected["app_settings"].update(PREFERENCES)
        self.assertEqual(rendered, expected)
        self.run_chezmoi("apply")
        self.assertEqual(self.read_config(), expected)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_second_apply_is_idempotent(self):
        self.target.write_text("schema_version = 9\n[app_settings]\nupdate_prompt_seen = false\n")
        self.run_chezmoi("apply")
        first = self.target.read_bytes()
        self.assertEqual(self.run_chezmoi("cat").stdout.encode(), first)
        self.run_chezmoi("apply")
        self.assertEqual(self.target.read_bytes(), first)
        self.assertFalse(self.read_config()["app_settings"]["update_prompt_seen"])

    def test_missing_config_starts_with_schema_seven(self):
        self.assertFalse(self.target.exists())
        rendered = tomllib.loads(self.run_chezmoi("cat").stdout)
        self.assertFalse(self.target.exists())
        self.assertEqual(rendered, {"schema_version": 7, "app_settings": PREFERENCES})
        self.run_chezmoi("apply")
        self.assertEqual(self.read_config(), rendered)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_empty_config_starts_with_schema_seven(self):
        self.target.write_text(" \n\t")
        self.run_chezmoi("apply")
        self.assertEqual(self.read_config(), {"schema_version": 7, "app_settings": PREFERENCES})

    def test_existing_config_does_not_receive_schema_version(self):
        self.target.write_text('[app_settings]\nfuture_preference = "keep"\n')
        self.run_chezmoi("apply")
        self.assertNotIn("schema_version", self.read_config())
        self.assertEqual(self.read_config()["app_settings"]["future_preference"], "keep")

    def test_malformed_toml_refuses_render_and_apply(self):
        original = '[app_settings\nappearance = "dark"\n'
        self.target.write_text(original)
        self.run_chezmoi("cat", succeeds=False)
        self.run_chezmoi("apply", succeeds=False)
        self.assertEqual(self.target.read_text(), original)

    def test_invalid_settings_type_refuses_render_and_apply(self):
        for value in ['"invalid"', '[]', 'true', '42']:
            with self.subTest(value=value):
                original = f"schema_version = 8\napp_settings = {value}\n"
                self.target.write_text(original)
                self.run_chezmoi("cat", succeeds=False)
                self.run_chezmoi("apply", succeeds=False)
                self.assertEqual(self.target.read_text(), original)


if __name__ == "__main__":
    unittest.main()
