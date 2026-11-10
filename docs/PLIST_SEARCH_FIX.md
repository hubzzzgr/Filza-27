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

Build result: [GitHub Actions 42741740457](https://github.com/hubzzzgr/Filza-27/actions/runs/42741740457)
succeeded for source `96fee868c4fad643f26541da5056f37b0e204951` on
`fix/plist-search-ui`. Download the [unsigned IPA and checksum](https://github.com/hubzzzgr/Filza-27/actions/runs/42741740457/artifacts/13729673454).
IPA SHA-256: `d215ab40f4eb440d486a5836a046eb9fb0197451733eecc6a209b7880b7c03f1`.
Final archive inspection confirmed the exact patched NIB hash above, linked
adapter and modern search controller, no deprecated controller class in packaged
interfaces, absent support-popup string, and no packaged music shortcut. No app,
simulator or runtime exploit was launched. Runtime editing/search parity remains
unverified; the expanded-tree fallback limitation described above applies.

## Follow-up after the device crash report

The first adapter build was not sufficient on the reporting device. The follow-up
makes all NIB outlet setters and awakeFromNib passive, adds NSCoding conformance,
and defers attachment to the next main-queue turn after the original viewDidLoad
returns. Search-result callbacks are gated until then. Hook installation is
idempotent and retried after class registration/launch. Runtime.log now records
adapter decode, entry/return of original viewDidLoad and deferred attachment.
The new exception reason/stack is still required to confirm the remaining crash
cause; compilation and packaging alone cannot establish a device fix.

NotActivatedNotice.m suppresses only presentation of alerts containing the literal
Not activated notice, through TGAlertController and UIKit's alert presentation.
It does not modify license/activation state or enable any paid functionality.
Other alerts are passed through. The prior support-popup module stays unlinked.
