"""Statically verify the legacy selector ABI in the pinned arm64 adapter dylib.

Reads Objective-C class/method metadata, including image-relative chained
pointers. It never loads or executes the dylib. Unknown layouts fail closed.
"""
import struct, sys
from pathlib import Path

b = Path(sys.argv[1]).read_bytes()
assert b[:4] == bytes.fromhex('cffaedfe'), 'expected little-endian Mach-O 64'
assert struct.unpack_from('<I', b, 4)[0] == 0x0100000c, 'expected arm64' 
u32=lambda o:struct.unpack_from('<I',b,o)[0]
u64=lambda o:struct.unpack_from('<Q',b,o)[0]
segments=[];classlists=[];p=32
for _ in range(u32(16)):
 cmd,size=struct.unpack_from('<II',b,p)
 if cmd==0x19:
  vm,vms,fo,fs=struct.unpack_from('<QQQQ',b,p+24);segments.append((vm,vms,fo,fs))
  for i in range(u32(p+64)):
   q=p+72+80*i;name=b[q:q+16].split(b'\0')[0]
   if name==b'__objc_classlist':classlists.append(struct.unpack_from('<QQI',b,q+32))
 p+=size
# The pinned arm64 dylib uses chained, unauthenticated image-relative pointers.
# Strip chain/high bits only after ordinary address translation fails.
def offset(addr):
 for a in (addr,addr&((1<<43)-1),addr&((1<<36)-1)):
  for vm,vs,fo,fs in segments:
   if vm<=a<vm+fs:return fo+a-vm
 raise ValueError(hex(addr))
def string(addr):
 o=offset(addr);return b[o:b.index(b'\0',o)].decode()
for addr,size,fo in classlists:
 for i in range(0,size,8):
  cl=offset(u64(fo+i));ro=offset(u64(cl+32)&~7)
  if string(u64(ro+24))!='FZPlistSearchControllerXX':continue
  ml=offset(u64(ro+32));flags,count=struct.unpack_from('<II',b,ml);entry=(flags&0xffff)&~3;methods={}
  for j in range(count):
   m=ml+8+entry*j
   if flags&0x80000000:
    # Relative method fields are signed offsets from each field's VM address.
    def vmaddr(fileoff):
     return next(vm+fileoff-fo for vm,vs,fo,fs in segments if fo<=fileoff<fo+fs)
    nameva=vmaddr(m)+struct.unpack_from('<i',b,m)[0]
    if not flags&0x40000000:nameva=u64(offset(nameva))
    typeva=vmaddr(m+4)+struct.unpack_from('<i',b,m+4)[0]
    impva=vmaddr(m+8)+struct.unpack_from('<i',b,m+8)[0]
   else:nameva,typeva,impva=struct.unpack_from('<QQQ',b,m)
   methods[string(nameva)]={'types':string(typeva),'implementation_file_offset':offset(impva)}
  required = {
   'hidNavigationBar': 'B16@0:8',
   'navigationControllerWillShowViewController:': 'v24@0:8@16',
   'navigationControllerDidShowViewController:': 'v24@0:8@16',
   'navigationControllerDidCancelShowingViewController:': 'v24@0:8@16',
   '_clearViewController': 'v16@0:8',
  }
  for selector, encoding in required.items():
   assert selector in methods, f'missing adapter method: {selector}'
   assert methods[selector]['types'] == encoding, f'wrong ABI for {selector}'
   assert methods[selector]['implementation_file_offset'] > 0, f'missing IMP: {selector}'
  print('Verified adapter method metadata and ABI:', ', '.join(required))
  sys.exit(0)
raise SystemExit('adapter class missing')
