# Plist search compatibility patch

## Located initialization

The proprietary Filza executable has TGPlistViewController/TGPlistNaviViewController
symbols and UISearchDisplayDelegate protocol/callback references. Its editor
implementation is not available in this repository. Static inspection found no
UISearchDisplayController class import or initWithSearchBar selector in that
executable. The concrete deprecated object is instantiated by unarchiving
Payload/Filza.app/TGPlistViewController.nib (NIBArchive, 2205 bytes).
Its outlets include searchContentsController, searchDisplayController,
searchResultsDataSource, searchResultsDelegate, delegate, treeTable and view.
All compiled NIBs, including the launch storyboard's NIBs, were scanned; this
was the only deprecated class record found.

## Replacement

scripts/patch-plist-search.py replaces the single class-table name
UISearchDisplayController with the equally sized FZPlistSearchControllerXX.
It checks the archive signature and occurrence count, and proves all other
bytes and the archive size are unchanged. It refuses unfamiliar layouts.

Original NIB SHA-256: 0c18ed9d23356e75f625f2ccfe47a8d9b4ee6e1ef31d05e8e9298e3d2247420a
Patched NIB SHA-256: 2631c52e3b2a44a44be18ccb448116b4e1ca73685c725a96338517fbcd573a8b

PlistSearchCompatibility.m implements that decoding/ABI adapter using a real
UISearchController. Only TGPlistViewController's legacy accessor/outlet and
viewDidLoad are hooked. No global UIKit assertion, SDK compatibility flag,
or other search screen is patched. The deprecated controller is never created
or subclassed. Modern results forward the existing datasource/delegate and
search lifecycle/filter callbacks. If no legacy filtering callback exists,
search finds text in the currently expanded tree rows and opens results using
the original table/delegate/index path. Nested collapsed rows in this fallback
must be expanded before searching. Scope-button/custom private selector behavior
and end-to-end editing remain device-unverified.

The original editor, save/add/delete/type editing and tree model remain in the
executable and NIB; none are replaced with a separate editor. This preserves
the existing implementation rather than attempting to recreate proprietary
editing behavior. Static inspection cannot establish complete runtime parity.

## Requested UI removals

FilzaSupportPrompt.m is no longer linked, so its Support Filza 27 popup and
replacement hooks are absent. Original activation/licensing behavior is not
modified by this change. The main toolbar filters the music action, packaged
music shortcuts are removed and stale music shortcut requests are ignored.
ByeTunes code remains available internally for shared pairing dependencies;
unrelated tools and access backends are not changed.

## Verification

Only static inspection, compilation, packaging and archive checks are permitted.
No simulator, device/app launch or runtime exploit test is used. Inspect the
patched archive for the replacement NIB class and linked adapter, absence of
the support popup string, and absence of packaged music shortcuts. Runtime
search/editing behavior must not be inferred from a successful build.
