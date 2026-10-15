// Accepted-engine comparator (v2.2 N1 corrective pass, Oct 12). Test support
// only; built by tools/catalog-harness/run.sh, never by the app.
//
// Records the run-transcript document (the same 22 seeded runs, picker and
// bookkeeping as the frozen legacy fixture) from the ACCEPTED draw engine:
// HEAD's UpgradeManager.swift, pinned by hash, either unedited (then the
// output must equal `legacy-run-transcripts.json` byte for byte) or with the
// reviewed N1 pool edits applied (then the output is what the current
// catalog-backed manager's replay must equal byte for byte — JF2b). Nothing
// here reads the catalog, the registry or the current manager.
import Foundation

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: comparator <out.json>\n".data(using: .utf8) ?? Data())
    exit(2)
}
do {
    let document = try ParityRuns.document()
    try ParityJSON.data(document, compact: true).write(to: URL(fileURLWithPath: args[1]))
    CodexManager.shared.resetAll()
    print("comparator: \((document["runs"] as? [Any])?.count ?? 0) runs → \(args[1])")
} catch {
    print("comparator failed: \(error)")
    exit(1)
}
