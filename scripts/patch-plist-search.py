#!/usr/bin/env python3
"""Length-preserving class-table patch, limited to the compiled plist editor NIB."""
from pathlib import Path
import hashlib, json, sys, struct
app = Path(sys.argv[1])
p = app / 'TGPlistViewController.nib'
before = p.read_bytes()
old, new = b'UISearchDisplayController', b'FZPlistSearchControllerXX'
assert len(old) == len(new) == 25
assert before.startswith(b'NIBArchive')
assert before.count(old) == 1, 'Unexpected plist NIB layout; refuse to patch'
class_table_offset = struct.unpack_from('<I', before, 46)[0]
assert class_table_offset <= before.index(old) < len(before), 'Legacy name is not in the class table'
after = before.replace(old, new)
assert len(before) == len(after)
assert before.split(old) == after.split(new), 'Bytes outside class name changed'
p.write_bytes(after)
info = {'resource':p.name,'old_class':old.decode(),'new_class':new.decode(),
        'before_sha256':hashlib.sha256(before).hexdigest(),'after_sha256':hashlib.sha256(after).hexdigest(),
        'length':len(after),'only_class_name_changed':True}
print(json.dumps(info, indent=2))
# Audit every packaged compiled interface, including storyboard bundles.
for resource in app.rglob('*'):
    if resource.suffix in ('.nib','.xib','.storyboard') and resource.is_file():
        assert old not in resource.read_bytes(), f'Unpatched legacy interface: {resource}'
