#!/usr/bin/env python3
"""Test Obsidian deployment without accessing the live vault."""

import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PLUGIN = "plugins/obsidian-excalidraw-plugin/data.json"
EXCALIDRAW = "obsidian-excalidraw-plugin:"
DISABLED_GLOBAL_COMMANDS = [
    "excalidraw-autocreate-newtab",
    "New Markdown Card",
    "Toggle Library",
    "Copy Selection for Agent",
    "Draft Markdown with Source",
    "Slideshow",
    "Downloaded/Mindmap Builder",
    "Downloaded/Select Elements of Type",
    "universal-add-file",
    "insert-link-to-element",
    "frame-settings",
    "excalidraw-open-sidepanel",
]
PALETTE_COMMANDS = [
    EXCALIDRAW + command for command in [
        "excalidraw-autocreate-newtab",
        "Downloaded/Mindmap Builder",
        "Downloaded/Select Elements of Type",
        "frame-settings",
        "excalidraw-open-sidepanel",
    ]
]
CANVAS_SCRIPT_COMMANDS = [
    "New Markdown Card",
    "Toggle Library",
    "Copy Selection as Image",
    "Draft Markdown with Source",
    "Slideshow",
    "Copy Selection for Agent",
]


class ObsidianConfigTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="obsidian-chezmoi-test-")
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name)
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        shutil.copytree(ROOT / "Atlas", self.source / "Atlas")
        self.vault = self.destination / "Atlas"
        self.settings = self.vault / ".obsidian"
        self.settings.mkdir(parents=True)
        config = self.root / "chezmoi.toml"
        config.write_text("")
        self.command = [
            "chezmoi", "--source", str(self.source),
            "--destination", str(self.destination),
            "--config", str(config),
            "--persistent-state", str(self.root / "state.boltdb"),
            "--cache", str(self.root / "cache"), "--no-tty", "--force",
        ]

    def write(self, name, value):
        path = self.settings / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def read(self, name):
        return json.loads((self.settings / name).read_text())

    def run_chezmoi(self, command, name=None, succeeds=True):
        target = self.settings / name if name else self.vault
        result = subprocess.run(
            [*self.command, command, str(target)],
            text=True, capture_output=True, check=False,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def test_plugin_merge_preserves_nested_settings_and_local_content(self):
        self.write(PLUGIN, {
            "autoexportSVG": False,
            "taskboneAPIkey": "synthetic-local-value",
            "library2": {"local": ["keep"]},
            "autostartScriptFailures": {"Other script": "local failure"},
            "autostartScripts": {"Other script": "deny"},
            "scriptEngineSettings": {
                "Slideshow": {"transitionDelay": 1200, "localOption": True},
                "Other script": {"value": 42},
            },
            "markdownImageSettings": {"defaults": {"width": 650}},
            "embeddableMarkdownDefaults": {"futurePreference": True},
            "pinnedScripts": ["Other script.md"],
        })
        self.run_chezmoi("apply", PLUGIN)
        actual = self.read(PLUGIN)
        self.assertTrue(actual["autoexportSVG"])
        self.assertEqual(actual["taskboneAPIkey"], "synthetic-local-value")
        self.assertEqual(actual["library2"], {"local": ["keep"]})
        self.assertEqual(actual["autostartScriptFailures"], {"Other script": "local failure"})
        self.assertEqual(actual["autostartScripts"]["Other script"], "deny")
        self.assertEqual(actual["autostartScripts"]["Canvas View Shortcuts"], "allow")
        self.assertEqual(actual["autostartScripts"]["Canvas Command Shortcuts"], "allow")
        self.assertEqual(actual["scriptEngineSettings"]["Slideshow"], {
            "transitionDelay": 500, "localOption": True,
        })
        self.assertEqual(actual["scriptEngineSettings"]["Other script"], {"value": 42})
        self.assertEqual(actual["markdownImageSettings"]["defaults"]["width"], 650)
        self.assertTrue(actual["embeddableMarkdownDefaults"]["futurePreference"])
        self.assertIn("Other script.md", actual["pinnedScripts"])

    def test_hotkeys_replace_old_bindings_and_preserve_editor_commands(self):
        unrelated = {
            "markdown:toggle-preview": [{"modifiers": ["Mod"], "key": "E"}],
            "editor:toggle-blockquote": [{"modifiers": ["Mod", "Shift"], "key": "A"}],
            "workspace:new-tab": [{"modifiers": ["Mod", "Shift"], "key": "N"}],
            "editor:insert-codeblock": [{"modifiers": ["Mod", "Shift"], "key": "C"}],
            "obsidian-icon-folder:add-icon": [{"modifiers": ["Mod", "Shift"], "key": "J"}],
            "local-plugin:option-action": [{"modifiers": ["Mod", "Alt"], "key": "Z"}],
        }
        original = {
            EXCALIDRAW + name: [{"modifiers": ["Mod", "Alt"], "key": "X"}]
            for name in DISABLED_GLOBAL_COMMANDS
        }
        original["pdf-plus:copy-link-to-selection"] = [
            {"modifiers": ["Mod", "Alt", "Shift"], "key": "P"},
        ]
        original.update(unrelated)
        self.write("hotkeys.json", original)
        rendered = json.loads(self.run_chezmoi("cat", "hotkeys.json").stdout)
        self.assertEqual(self.read("hotkeys.json"), original)
        self.run_chezmoi("apply", "hotkeys.json")
        actual = self.read("hotkeys.json")
        self.assertEqual(actual, rendered)
        for command, binding in unrelated.items():
            self.assertEqual(actual[command], binding, command)
        for command in DISABLED_GLOBAL_COMMANDS:
            self.assertEqual(actual[EXCALIDRAW + command], [], command)
        self.assertEqual(actual["pdf-plus:copy-link-to-selection"], [
            {"modifiers": ["Mod", "Shift"], "key": "K"},
        ])
        self.assertNotIn(EXCALIDRAW + "Toggle Canvas View Mode", actual)
        self.assertNotIn(EXCALIDRAW + "Copy Selection as Image", actual)
        self.run_chezmoi("apply", "hotkeys.json")
        self.assertEqual(self.read("hotkeys.json"), actual)

    def test_palette_pins_preserve_order_and_other_settings_without_duplicates(self):
        original = {
            "pinned": ["local:first", PALETTE_COMMANDS[2], "local:last", "local:first"],
            "localPreference": {"keep": True},
        }
        self.write("command-palette.json", original)
        expected = {
            "pinned": ["local:first", PALETTE_COMMANDS[2], "local:last",
                       *[command for command in PALETTE_COMMANDS if command != PALETTE_COMMANDS[2]]],
            "localPreference": {"keep": True},
        }
        rendered = json.loads(self.run_chezmoi("cat", "command-palette.json").stdout)
        self.assertEqual(rendered, expected)
        self.assertEqual(self.read("command-palette.json"), original)
        self.run_chezmoi("apply", "command-palette.json")
        self.assertEqual(self.read("command-palette.json"), expected)
        first = (self.settings / "command-palette.json").read_bytes()
        self.run_chezmoi("apply", "command-palette.json")
        self.assertEqual((self.settings / "command-palette.json").read_bytes(), first)

    def test_palette_rejects_invalid_pin_list(self):
        for invalid in [None, "wrong type", {}]:
            with self.subTest(invalid=invalid):
                original = {"pinned": invalid}
                self.write("command-palette.json", original)
                self.run_chezmoi("cat", "command-palette.json", succeeds=False)
                self.run_chezmoi("apply", "command-palette.json", succeeds=False)
                self.assertEqual(self.read("command-palette.json"), original)

    def test_enabled_lists_preserve_local_choices_without_duplicates(self):
        self.write("appearance.json", {
            "theme": "system", "accentColor": "#123456",
            "enabledCssSnippets": ["local-css", "excalidraw-compact-hint"],
        })
        self.write("community-plugins.json", ["local-plugin", "pdf-plus"])
        self.run_chezmoi("apply", "appearance.json")
        self.run_chezmoi("apply", "community-plugins.json")
        self.assertEqual(self.read("appearance.json"), {
            "theme": "system", "accentColor": "#123456",
            "enabledCssSnippets": ["local-css", "excalidraw-compact-hint", "excalidraw-markdown-cards"],
        })
        self.assertEqual(self.read("community-plugins.json"), [
            "local-plugin", "pdf-plus", "obsidian-excalidraw-plugin",
        ])

    def test_fresh_deployment_is_complete_and_idempotent(self):
        self.run_chezmoi("apply")
        first = {str(p.relative_to(self.vault)): p.read_bytes()
                 for p in self.vault.rglob("*") if p.is_file()}
        self.run_chezmoi("apply")
        second = {str(p.relative_to(self.vault)): p.read_bytes()
                  for p in self.vault.rglob("*") if p.is_file()}
        self.assertEqual(first, second)
        scripts = self.vault / "Assets/Scripts/Excalidraw"
        for command in [*self.read("hotkeys.json"), *self.read("command-palette.json")["pinned"]]:
            name = command.removeprefix(EXCALIDRAW)
            if name[0].isupper():
                self.assertTrue((scripts / f"{name}.md").is_file(), name)
        for name in CANVAS_SCRIPT_COMMANDS:
            self.assertTrue((scripts / f"{name}.md").is_file(), name)
        self.assertEqual(self.read("command-palette.json")["pinned"], PALETTE_COMMANDS)
        plugin = self.read(PLUGIN)
        self.assertTrue((self.vault / plugin["templateFilePath"]).is_file())
        for name in plugin["autostartScripts"]:
            self.assertTrue((scripts / f"{name}.md").is_file(), name)
        for path in plugin["pinnedScripts"]:
            self.assertTrue((self.vault / path).is_file(), path)
        self.assertFalse((self.vault / "dot_obsidian").exists())
        self.assertFalse((scripts / "README.md").exists())

    def test_apply_preserves_unmanaged_vault_files(self):
        examples = {
            "Library/Canvas/My drawing.md": "private drawing",
            ".obsidian/workspace.json": "private session state",
            ".obsidian/plugins/other-plugin/data.json": "private plugin state",
            "Assets/Scripts/Excalidraw/My script.md": "local script",
        }
        for name, value in examples.items():
            path = self.vault / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        self.run_chezmoi("apply")
        for name, value in examples.items():
            self.assertEqual((self.vault / name).read_text(), value)

    def test_invalid_json_does_not_replace_any_target(self):
        for name in [PLUGIN, "hotkeys.json", "command-palette.json", "appearance.json", "community-plugins.json"]:
            for original in ["{broken", '"wrong type"', "null"]:
                with self.subTest(name=name, original=original):
                    path = self.settings / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(original)
                    self.run_chezmoi("cat", name, succeeds=False)
                    self.run_chezmoi("apply", name, succeeds=False)
                    self.assertEqual(path.read_text(), original)

    def test_upstream_files_match_recorded_hashes(self):
        records = json.loads((ROOT / "docs/excalidraw/upstream-files.json").read_text())
        self.assertEqual(len(records), 6)
        for record in records:
            self.assertEqual(hashlib.sha256((ROOT / record["file"]).read_bytes()).hexdigest(),
                             record["sha256"], record["file"])


if __name__ == "__main__":
    unittest.main()
