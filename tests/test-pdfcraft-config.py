#!/usr/bin/env python3
"""Test PdfCraft preferences with Chezmoi in temporary directories."""

import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = pathlib.Path("Library/Application Support/PdfCraft/modify_app.ron.tmpl")
TARGET_FILE = pathlib.Path("Library/Application Support/PdfCraft/app.ron")

# The other two entries of the eframe map. The script must keep them byte for byte.
EGUI = '    "egui": "(options:(theme_preference:System,zoom_factor:1.0),data:([]))",\n'
WINDOW = '    "window": "(fullscreen:false,maximized:false)",\n'


def app_ron(preferences):
    """Return an app.ron as PdfCraft 0.21 writes it, around an escaped preferences literal."""
    return '{\n    "pdfcraft": "' + preferences + '",\n' + EGUI + WINDOW + "}"


# Written the way PdfCraft writes it: compact JSON with sorted keys, then escaped
# by RON with Rust's char::escape_debug, so a combining accent becomes \u{301}, an
# apostrophe becomes \', and a JSON newline escape becomes \\n.
LIVE = app_ron(
    r'{\"author\":\"Tester\",\"javascript\":true,'
    r'\"recent\":[{\"name\":\"pla\u{301}n\'s.pdf\",\"pages\":3,\"path\":\"/tmp/pla\u{301}n\'s.pdf\"}],'
    r'\"trusted\":[\"-----BEGIN CERTIFICATE-----\\nAAAA\\n-----END CERTIFICATE-----\\n\"],'
    r'\"update_check_at_start\":true,\"zoom\":87.5}'
)
# The same preferences after the script: only update_check_at_start changes. The
# script writes characters as they are and escapes only backslashes and quotes.
EXPECTED = app_ron(
    r'{\"author\":\"Tester\",\"javascript\":true,'
    '\\"recent\\":[{\\"name\\":\\"plán\'s.pdf\\",\\"pages\\":3,\\"path\\":\\"/tmp/plán\'s.pdf\\"}],'
    r'\"trusted\":[\"-----BEGIN CERTIFICATE-----\\nAAAA\\n-----END CERTIFICATE-----\\n\"],'
    r'\"update_check_at_start\":false,\"zoom\":87.5}'
)


class PdfCraftConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pdfcraft-chezmoi-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        self.target = self.destination / TARGET_FILE
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
            capture_output=True,
            check=False,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stderr.decode())
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout.decode())
        return result

    def write_target(self, text):
        self.target.write_bytes(text.encode("utf-8"))

    def read_target(self):
        return self.target.read_bytes().decode("utf-8")

    def test_apply_changes_only_the_managed_preference(self):
        self.write_target(LIVE)
        self.assertEqual(self.run_chezmoi("cat").stdout.decode("utf-8"), EXPECTED)
        self.assertEqual(self.read_target(), LIVE)
        self.run_chezmoi("apply")
        self.assertEqual(self.read_target(), EXPECTED)

    def test_matching_file_is_left_byte_for_byte(self):
        already = LIVE.replace(r'\"update_check_at_start\":true', r'\"update_check_at_start\":false')
        self.write_target(already)
        self.assertEqual(self.run_chezmoi("cat").stdout.decode("utf-8"), already)
        self.run_chezmoi("apply")
        self.assertEqual(self.read_target(), already)

    def test_second_apply_is_idempotent(self):
        self.write_target(LIVE)
        self.run_chezmoi("apply")
        first = self.target.read_bytes()
        self.run_chezmoi("apply")
        self.assertEqual(self.target.read_bytes(), first)

    def test_wrong_type_is_replaced(self):
        self.write_target(LIVE.replace(r'\"update_check_at_start\":true', r'\"update_check_at_start\":0'))
        self.run_chezmoi("apply")
        self.assertEqual(self.read_target(), EXPECTED)

    def test_missing_file_starts_with_the_managed_preferences(self):
        self.assertFalse(self.target.exists())
        self.run_chezmoi("apply")
        self.assertEqual(self.read_target(), '{\n    "pdfcraft": "{\\"update_check_at_start\\":false}",\n}\n')

    def test_file_without_preferences_gets_the_entry(self):
        self.write_target("{\n" + EGUI + WINDOW + "}")
        self.run_chezmoi("apply")
        self.assertEqual(
            self.read_target(),
            '{\n    "pdfcraft": "{\\"update_check_at_start\\":false}",\n' + EGUI + WINDOW + "}",
        )

    def test_unreadable_files_refuse_render_and_apply(self):
        cases = {
            "not a map": '("pdfcraft": "{}")',
            "unterminated string": '{\n    "pdfcraft": "{\\"a\\":1}',
            "unknown escape": '{\n    "pdfcraft": "{\\"a\\":\\"\\q\\"}",\n}',
            "bad unicode escape": '{\n    "pdfcraft": "{\\"a\\":\\"\\u{zz}\\"}",\n}',
            "preferences not JSON": '{\n    "pdfcraft": "{broken",\n}',
            "preferences not an object": '{\n    "pdfcraft": "[]",\n}',
            "text after the map": '{\n    "pdfcraft": "{}",\n} extra',
        }
        for name, original in cases.items():
            with self.subTest(name=name):
                self.write_target(original)
                self.run_chezmoi("cat", succeeds=False)
                self.run_chezmoi("apply", succeeds=False)
                self.assertEqual(self.read_target(), original)


if __name__ == "__main__":
    unittest.main()
