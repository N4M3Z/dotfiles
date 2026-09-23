# Slideshow maintenance

`Slideshow.md` is a local fork maintained in N4M3Z/dotfiles.
Zsolt Viczián wrote the upstream script. The attribution and upstream links remain in the script.
Deploy the maintained script and its SVG icon together to `Atlas/Assets/Scripts/Excalidraw/`.
Tests do not execute the script in Obsidian.

## Source

- [Upstream script at commit a8182899](https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/a8182899b760fe09b24ba60c5833d5985d3a5f8c/ea-scripts/Slideshow.md)
- Upstream build: `2026-09-15T13:48:51.367Z`
- Original SHA-256: `94c658070da0cc15e552a9f2c944011f6fcbe45ed41d1700adfda97003603204`
- Patched SHA-256: `bf82f082ed31da39c3a4ec2ccf9670246334903f326369447c6ce0e739806983`
- Installed path: `Atlas/Assets/Scripts/Excalidraw/Slideshow.md`
- Command: `obsidian-excalidraw-plugin:Slideshow`
- Autostart and script settings key: `Slideshow`
- Investigated environment: Excalidraw 2.27.3, Obsidian 1.14.2, macOS.

## Changes

A source note could become active while the inactive drawing still owned DOM fullscreen.
The presentation controller remained active, and the Obsidian window lost normal input controls.
The JavaScript thread still responded.

The patch adds two presentation-scoped Obsidian workspace listeners.
They end the presentation when another leaf becomes active or the host drawing changes.
The presenter leaf remains exempt.
Exit removes both listeners.
Failed startup also releases controller resources.

Cleanup exits the drawing's DOM fullscreen before presenter cleanup and native window restoration.
It awaits the DOM fullscreen exit promise.
It avoids scene restoration if the leaf or file now contains another drawing.

Presentation setup now preserves the drawing's frame rendering preferences.
The upstream script disabled frame rendering temporarily, then restored it during exit.
Source navigation could save that temporary state before exit restored it.
The local script removes both the temporary override and its exit restoration.
This prevents presentation startup from changing the saved frame settings.

Window snapshots now include the original native fullscreen state.
Restoration preserves that state where the operating system permits it.
It skips bounds changes while native fullscreen remains active, including after the existing timeout.

The default transition duration changes from 1,000 ms to 500 ms.
An existing saved duration still overrides this default.
The patch does not add a keyboard handler.
Cmd+Shift starts a new fullscreen presentation when both modifiers remain pressed during command execution.
Cleared modifiers also start fullscreen, so Cmd+Shift+Enter has the same result in both states.
Cmd or Ctrl alone still opens the sidepanel. Option alone still starts windowed.
Shift alone retains its resume behavior.

## Validation

Run `node --test tests/excalidraw-slideshow.test.cjs` from the repository root.
All 36 focused tests pass.
The tests parse the complete script and execute its affected production sections with controlled mocks.
They cover navigation, cleanup order, listener disposal, file replacement, fullscreen ownership, native restoration, frame preferences, modifiers, and failed startup.

The previous live computer-use test confirmed that Cmd+Option+P started fullscreen with presentation and view mode active.
One Backspace ended the presentation, cleared DOM fullscreen, and restored edit mode.
Those checks used the previous shortcut map.

The Cmd+Shift+Enter desktop check started playback with the fullscreen launch flag enabled.
Native fullscreen restoration and Backspace exit remain unverified in that check.
Computer use reported a hidden renderer while the exit promise waited for window restoration or resize.
The test does not establish a user-visible application freeze.
After saving the drawings, a vault reload cleared the temporary presentation.
The cheatsheet reopened in edit mode with its 261 objects and both shortcut handlers.

Full navigation and native window restoration tests remain pending.
Test source links from both windowed and native fullscreen Obsidian.
Check the active leaf, DOM fullscreen owner, window input, and native fullscreen state after navigation.
Presenter focus and repeated presentation starts also remain pending.

## Limits and updates

The link hook remains synchronous and still permits native link navigation.
The workspace listeners provide cleanup after navigation when the hook does not run.
They do not serialize note navigation behind the fullscreen promise.

The tests establish cleanup behavior with mocked Obsidian and Electron APIs.
They do not prove that macOS rendering or accessibility faults are resolved.
Native fullscreen restoration depends on asynchronous operating system transitions.
Display movement and ordinary slideshow behavior remain upstream behavior.
Frame labels and outlines remain visible during presentation when the drawing's preferences enable them.
Cmd+Shift-click on the script also starts fullscreen because the script uses the same modifier resolver.
The fullscreen exception applies only without Ctrl or Option.

This copy is maintained separately from the downloaded scripts.
Review upstream changes against the pinned source, apply selected changes here, and run the tests before deployment.
Keep the icon, shortcut, Autostart entry, and script settings under the `Slideshow` name.
