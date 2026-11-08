// Filza's single-provider Mond coordinator. Copied after upstream staging.
import Foundation

private var list_cache: [String: [String]] = [:]
private let list_cache_lock = NSLock()
private var grantInFlight = false

func grant_access(_ path: String, probe_leaf: String?, msg: String) -> Int64 {
    var pathC = path.utf8CString.map { Int8($0) }
    let handle: Int64
    if let probe_leaf {
        var leafC = probe_leaf.utf8CString.map { Int8($0) }
        handle = mond_bad_query(&pathC, true, nil, false, &leafC)
    } else {
        handle = mond_bad_query(&pathC, true, nil, false, nil)
    }
    if handle < 0 {
        print("(worse_query) \(msg) failed: \(FilzaWorseQueryErrorDescription(handle)) [\(handle)]")
    } else {
        print("(worse_query) \(msg): read access verified; write access untested; handle \(handle)")
    }
    return handle
}

func grant_mg() -> Int64 {
    grant_access(MondCurrentTweakPaths.gestalt_dir,
                 probe_leaf: "com.apple.MobileGestalt.plist", msg: "MobileGestalt")
}

func list_containers(_ root: String) -> [String] {
    guard FilzaWorseQueryReady() else { return [] }
    var normalized = root
    if normalized.hasPrefix("/private/") { normalized.removeFirst(8) }
    if normalized.hasSuffix("/") { normalized.removeLast() }
    list_cache_lock.lock()
    defer { list_cache_lock.unlock() }
    if let cached = list_cache[normalized], !cached.isEmpty { return cached }
    var pathC = normalized.utf8CString.map { Int8($0) }
    guard let raw = mond_bad_query_list(&pathC, 2_000_000) else { return [] }
    defer { free(raw) }
    let paths = String(cString: raw).split(whereSeparator: \.isNewline).map(String.init)
    if !paths.isEmpty { list_cache[normalized] = paths }
    return paths
}

func grant_pb() -> Int64 {
    guard FilzaWorseQueryReady() else { return -256 }
    do {
        let container = try MondCurrentPosterBackend.find_pb_container()
        let directory = MondCurrentPosterBackend.descriptors_url(container: container,
            ext: MondCurrentPosterBackend.collections_ext)
        _ = try? MondCurrentPosterBackend.ensure_directory(at: directory.path)
        return grant_access(directory.path, probe_leaf: nil, msg: "PosterBoard")
    } catch {
        print("(worse_query) PosterBoard discovery failed: \(error.localizedDescription). This does not identify a kernel rejection.")
        return -1
    }
}

func grant_apps() -> Int64 {
    guard FilzaWorseQueryReady() else { return -256 }
    for root in MondCurrentPosterBackend.container_roots {
        guard let target = list_containers(root).first else { continue }
        return grant_access(target, probe_leaf: nil, msg: "Container \(target)")
    }
    print("(worse_query) No app containers discovered within the inode scan limit.")
    return -1
}

func grant_all(state: MondCurrentAppState) {
    guard !grantInFlight else {
        print("(worse_query) Access request already running; skipping duplicate.")
        return
    }
    guard FilzaWorseQueryReady() else {
        state.granting_pb = false
        state.granting_apps = false
        state.granting_mg = false
        state.pb_granted = false
        state.apps_granted = false
        state.mg_granted = false
        state.exploit_succeeded = false
        print("(worse_query) Setup required: \(FilzaWorseQueryConfigurationStatus())")
        print("(worse_query) Skipping MobileGestalt, PosterBoard and container requests until the App Group is accessible.")
        return
    }
    grantInFlight = true
    state.pb_granted = nil
    state.apps_granted = nil
    state.mg_granted = nil
    state.granting_pb = true
    state.granting_apps = true
    state.granting_mg = true
    DispatchQueue.global(qos: .userInitiated).async {
        let mg = grant_mg()
        let poster = grant_pb()
        let apps = grant_apps()
        DispatchQueue.main.async {
            grantInFlight = false
            state.granting_pb = false
            state.granting_apps = false
            state.granting_mg = false
            state.pb_granted = poster >= 0
            state.apps_granted = apps >= 0
            state.mg_granted = mg >= 0
            state.exploit_succeeded = mg >= 0 && poster >= 0 && apps >= 0
        }
    }
}
