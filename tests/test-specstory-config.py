#!/usr/bin/env python3
"""Test the SpecStory CLI config merge with Chezmoi in temporary directories."""

import pathlib
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = pathlib.Path("dot_specstory/cli/modify_config.toml")
ENFORCED = {
    "cloud_sync": {"enabled": False},
    "analytics": {"enabled": False},
    "version_check": {"enabled": False},
    "telemetry": {"endpoint": "localhost:4317", "prompts": True},
}


class SpecStoryConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="specstory-chezmoi-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        self.target = self.destination / ".specstory/cli/config.toml"
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

    def assert_enforced(self, config):
        for table, values in ENFORCED.items():
            for key, value in values.items():
                self.assertEqual(config[table][key], value, f"{table}.{key}")

    def test_specstory_keys_survive_and_privacy_keys_win(self):
        self.target.write_text(
            '[cloud_sync]\nenabled = true\n\n'
            '[telemetry]\nendpoint = "collector.example:4317"\nservice_name = "specstory"\n\n'
            '[providers]\nlast_used = "claude"\n'
        )
        self.run_chezmoi("apply")
        config = tomllib.loads(self.target.read_text())
        self.assert_enforced(config)
        self.assertEqual(config["telemetry"]["service_name"], "specstory")
        self.assertEqual(config["providers"]["last_used"], "claude")

    def test_missing_config_gets_the_enforced_keys(self):
        self.run_chezmoi("apply")
        self.assert_enforced(tomllib.loads(self.target.read_text()))

    def test_second_apply_is_idempotent(self):
        self.target.write_text('[providers]\nlast_used = "codex"\n')
        self.run_chezmoi("apply")
        first = self.target.read_bytes()
        self.run_chezmoi("apply")
        self.assertEqual(self.target.read_bytes(), first)

    def test_malformed_toml_refuses_render_and_apply(self):
        self.target.write_text("not = = toml\n")
        self.run_chezmoi("cat", succeeds=False)
        self.run_chezmoi("apply", succeeds=False)
        self.assertEqual(self.target.read_text(), "not = = toml\n")

    def test_non_table_value_refuses_render(self):
        self.target.write_text('telemetry = "off"\n')
        self.run_chezmoi("cat", succeeds=False)


if __name__ == "__main__":
    unittest.main()
