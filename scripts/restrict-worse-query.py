#!/usr/bin/env python3
"""Last staging transform: one access provider, no alternate exploit controls."""
from pathlib import Path
import re


def remove_block(text, marker):
    start = text.index(marker)
    brace = text.index('{', start)
    depth = 0
    for end in range(brace, len(text)):
        depth += (text[end] == '{') - (text[end] == '}')
        if depth == 0:
            return text[:start] + text[end+1:]
    raise SystemExit(f'Unbalanced block: {marker}')

root = Path('ThirdParty/mond-current/Generated/Mond')
p = root / 'exploit_unsbx.swift'
s = p.read_text()
s = remove_block(s, '    if MondEmbeddedParity.defaults.string(forKey: "method") == "cmg"')
p.write_text(s)
p = root / 'views_app_ContentView.swift'
s = p.read_text().replace('method == "cmg" || ', '').replace('Text("HouseArrest")', 'Text("Containers")')
s = remove_block(s, '                    if method == "cmg"')
p.write_text(s)
p = root / 'views_app_SettingsView.swift'
s = p.read_text()
a = s.index('    var valid: Bool {'); b = s.index('    var body:', a); s = s[:a] + s[b:]
a = s.index('                    Picker("Method"'); b = s.index('                    Button {', a)
s = s[:a] + '                    Text("worse_query")\n' + s[b:]
a = s.index('                    Text(method == "cmg"'); b = s.index('\n', a)
s = s[:a] + '                    Text("Requires a dedicated, provisioned App Group. Access depends on the target and iOS build.")' + s[b:]
a = s.index('                Section {\n                    TextField("Sandbox Extension Token.')
b = s.index('                Section {\n                    MondCurrentPlainToggle', a)
s = s[:a] + s[b:]
a = s.index('                Section {\n                    Button {\n                        show_confirm = true')
b = s.index('                Section {\n                    MondCurrentCreditsRow', a)
s = s[:a] + s[b:]
s = re.sub(r'^.*@AppStorage\("(method|token)".*\n', '', s, flags=re.M)
s = s.replace('The bad_query exploit', 'worse_query')
s = '\n'.join(line for line in s.splitlines() if 'His work on the MCM bug class' not in line) + '\n'
p.write_text(s)
p = root / 'helpers_utils.swift'
s = p.read_text(); a = s.index('// respring.swift:'); b = s.index('final class MondCurrentAppState:', a)
s = s[:a] + s[b:]
s = s.replace('        show_respring = true', '''        MondCurrentAlertinator.shared.alert(title: "Restart manually",
            body: "This build has no respring exploit. Restart the app or device manually if needed.")''')
p.write_text(s)
for name in ('exploit_cmg.swift', 'helpers_sbx.swift'):
    (root / name).unlink(missing_ok=True)
for name in ('mond_bad_query.c', 'mond_bad_query.h'):
    (root.parent / name).unlink(missing_ok=True)

root = Path('ThirdParty/3105/Sources')
p = root / 'ContainerStore.swift'
s = p.read_text().replace('KernelExploit.requiresSandboxEscape, !KernelExploit.hasSandboxAccess()', '!MCMBridgeAvailable()')
s = s.replace('ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26', 'true')
p.write_text(s)
p = root / 'ThreeOneOSFiveContentView.swift'
s = remove_block(p.read_text(), '            if appState.kernelExploitApplicable')
s = s.replace('Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))', 'Text(appState.isSupported ? "worse_query prerequisites available" : "worse_query prerequisites unavailable")')
s = s.replace('Text(language.text("settings.supported_range_summary"))', 'Text("worse_query only. Device compatibility is unverified; each file operation must obtain access.")')
p.write_text(s)
p = root / 'ThreeOneOSFiveSettingsView.swift'
s = p.read_text(); a = s.index('                Section {\n                    HStack {'); b = s.index('                Section(language.text("settings.social_media"))', a)
s = s[:a] + '''                Section("Filesystem access") {
                    Text("worse_query only")
                    Text("Requires a provisioned App Group. Successful compilation does not verify device compatibility.")
                }

''' + s[b:]
p.write_text(s)
for name in ('KernelExploit.swift', 'SBX.swift'):
    (root / name).unlink(missing_ok=True)
print('Applied worse_query-only backend and UI restrictions')
