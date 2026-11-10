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

Previous build (reported still crashing): [GitHub Actions 42741740457](https://github.com/hubzzzgr/Filza-27/actions/runs/42741740457)
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

Follow-up build [42746066500](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500) succeeded for source
`3945c2df50bb38cb2e9fd165abc746ffec23e72d` on
`fix/plist-lifecycle-default-group`. [Download the sideloadable IPA](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500/artifacts/13731775630).
IPA SHA-256: `048e7241a3b0e5c47d37eaa7b2b97d79035d4a9bec5419aa38693c852983d63a`.
Static inspection verified the exact NIB hash, linked deferred adapter and notice
filter, absent music shortcuts and removed-backend markers, no provisioning
profile, and an ad-hoc main-executable signature with the default App Group
request. This request still requires SideStore provisioning/re-signing. No app,
simulator or exploit was launched. The remaining crash cause is unconfirmed;
provide the latest exception reason/stack or `Documents/FilzaSlop Logs/LastException.txt`
and the corresponding `Runtime.log` entries to locate it. Search/editing parity
remains unverified and the expanded-tree fallback limitation remains.

## Reported UIKit navigation selector crash

The reproduced exception identifies `-[FZPlistSearchControllerXX hidNavigationBar]`
as the missing selector. The original adapter metadata confirms it is absent.
This is a concrete adapter ABI gap; it is separate from the earlier suspected
NIB timing problem. It is not evidence about worse_query access or provisioning.

The adapter now explicitly implements `hidNavigationBar` with Boolean return
`NO`: it has never hidden a bar through the legacy controller, and modern search
owns its presentation. It also implements the reference legacy navigation
will-show/did-show/cancel callbacks and passive `_clearViewController` teardown.
Leaving the editor ends active modern search without creating UI during a
transition. No global unrecognized-selector swallowing/forwarding is added.
The NIB replacement, original editor implementation, search filtering callbacks,
expanded-tree fallback and App Group request are preserved.

Reference selector signatures were checked against the
[UIKitCore runtime header](https://github.com/nst/iOS-Runtime-Headers/blob/master/PrivateFrameworks/UIKitCore.framework/UISearchDisplayController.h).
CI statically reads the adapter's Objective-C method metadata and exact arm64
type encodings with `scripts/verify-plist-search-abi.py`, including Boolean
`hidNavigationBar` and void navigation/teardown methods. This checker does not
load or execute the library. It rejects the prior artifact missing the method.
Private UIKit selectors can vary across OS versions; this addresses the reported
selector and the inspected neighboring callbacks, not every private legacy API.
Runtime plist/search parity and exploit compatibility remain unverified.
