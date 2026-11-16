import Foundation
import CryptoKit
import SwitchCore
import SwitchStorage

/// Shared histories are checked in place. Their size must not be limited by the attachment-copy budget.
enum ConversationHistory {
    struct Scope {
        var project: URL
        var cli: String
        var priorSessionIDs: [String]
        var record: JSONValue = .object([:])
        var owners: Set<String> { Set([cli] + priorSessionIDs) }
    }
    struct Scan {
        var digest: String
        var agents: Set<String>
        var referenceSessions: [String: Set<String?>]
    }

    static func scan(_ file: URL) throws -> Scan {
        var pending = Data(), agents = Set<String>(), referenceSessions: [String: Set<String?>] = [:]
        func line(_ data: Data) throws {
            guard !data.isEmpty else { return }
            guard let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw invalid }
            if let result = row["toolUseResult"] as? [String: Any], let agent = result["agentId"] as? String {
                guard !agent.isEmpty, agent.count <= 128,
                      agent.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { throw SwitchError.unsafePath }
                agents.insert(agent)
                if (referenceSessions[agent]?.count ?? 0) < 2 {
                    let origin = (row["sessionId"] as? String).flatMap { id in
                        id.count == 36 && UUID(uuidString: id) != nil ? id : nil
                    }
                    referenceSessions[agent, default: []].insert(origin)
                }
                guard agents.count <= 512 else { throw invalid }
            }
        }
        let hash = try hash(file) { chunk in
            let parts = chunk.split(separator: 10, omittingEmptySubsequences: false)
            for (index, part) in parts.enumerated() {
                pending.append(contentsOf: part)
                guard pending.count <= 64 * 1024 * 1024 else { throw invalid }
                if index < parts.count - 1 { try line(pending); pending.removeAll(keepingCapacity: true) }
            }
        }
        try line(pending)
        return Scan(digest: hash, agents: agents, referenceSessions: referenceSessions)
    }

    /// Project directories that hold a CLI session's main transcript.
    static func homes(of cli: String, in projects: [URL]) throws -> [URL] {
        try projects.filter { project in
            guard try project.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { return false }
            let file = project.appendingPathComponent(cli + ".jsonl")
            try SafeFiles.validateAncestors(file)
            return FileManager.default.fileExists(atPath: file.path)
        }
    }

    static func scope(_ session: Conversation, projects: [URL], desktop: URL) throws -> Scope {
        guard let cli = session.cliSessionID, UUID(uuidString: cli) != nil else { throw SwitchError.unsafePath }
        let matches = try homes(of: cli, in: projects)
        guard matches.count == 1, let project = matches.first else {
            throw SwitchError.blocked(L10n.tr("This conversation's local history is missing or ambiguous. Nothing was transferred."))
        }
        let record = try SafeFiles.json(SafeFiles.child(session.recordRelativePath, of: desktop), limit: 2 * 1024 * 1024)
        let lineage = ConversationLineage.read(record, sessionID: session.sessionID)
        guard record["sessionId"].string == session.sessionID, record["cliSessionId"].string == cli,
              !lineage.invalid, lineage.parent == session.parentSessionID else { throw SwitchError.changed }
        return Scope(project: project, cli: cli, priorSessionIDs: try priorSessionIDs(record), record: record)
    }

    static func ancestors(of session: Conversation, in tree: ConversationTree) throws -> [Conversation] {
        guard tree.isValid(session) else { throw ConversationTree.unresolved }
        let family = Dictionary(grouping: tree.members(of: session), by: { $0.sessionID.lowercased() })
        var result: [Conversation] = [], current = session, seen: Set<String> = [session.id]
        while let parent = current.parentSessionID {
            guard let matches = family[parent.lowercased()], matches.count == 1, let next = matches.first,
                  seen.insert(next.id).inserted, seen.count <= 128 else { throw ConversationTree.unresolved }
            result.append(next); current = next
        }
        return result
    }

    static func priorSessionIDs(_ record: JSONValue) throws -> [String] {
        let value = record["priorCliSessionIds"]
        if value == .null { return [] }
        guard let entries = value.array else { throw invalid }
        return try Array(Set(entries.map {
            guard let id = $0.string, UUID(uuidString: id) != nil else { throw invalid }
            return id.lowercased()
        })).sorted()
    }

    static func dependencies(_ history: URL, project: URL, cli: String, priorSessionIDs: [String],
                             inheritedScopes: [Scope] = [], projects: [URL] = []) throws
        -> (files: [String: FileExpectation], agentHistories: Int, historicalAgentHistories: Int, inheritedAgentHistories: Int) {
        var scopes = [Scope(project: project, cli: cli, priorSessionIDs: priorSessionIDs)] + inheritedScopes
        var pending = [(history, cli, 0)], seen = Set<URL>(), files: [String: FileExpectation] = [:], historical = 0, inherited = 0
        var bound: [String: Int] = [:], recorded: [String: Set<String>] = [:]
        /// A copied row keeps naming the session that wrote it, which may be absent from Desktop's index.
        /// That session's project can supply the history only when its transcript is unique and records the agent.
        func binding(_ origin: String, agent: String) throws -> Int? {
            if bound[origin] == nil {
                let homes = try homes(of: origin, in: projects)
                guard homes.count == 1, let home = homes.first else { return nil }
                recorded[origin] = try scan(home.appendingPathComponent(origin + ".jsonl")).agents
                scopes.append(Scope(project: home, cli: origin, priorSessionIDs: []))
                bound[origin] = scopes.count - 1
            }
            return recorded[origin]?.contains(agent) == true ? bound[origin] : nil
        }
        func candidate(_ name: String, owner: String, scope: Scope) throws -> (URL, String)? {
            let nested = try SafeFiles.child(owner + "/subagents/" + name, of: scope.project)
            let flat = try SafeFiles.child(name, of: scope.project)
            if FileManager.default.fileExists(atPath: nested.path) { return (nested, owner) }
            if FileManager.default.fileExists(atPath: flat.path) { return (flat, owner) }
            let alternatives = try scope.owners.subtracting([owner]).sorted().compactMap { id -> (URL, String)? in
                let file = try SafeFiles.child(id + "/subagents/" + name, of: scope.project)
                return FileManager.default.fileExists(atPath: file.path) ? (file, id) : nil
            }
            guard alternatives.count <= 1 else { throw missingAgent }
            return alternatives.first
        }
        while let (file, owner, scopeIndex) = pending.popLast() {
            guard seen.insert(file).inserted else { continue }
            guard seen.count <= 513 else { throw invalid }
            let scan = try scan(file)
            files[file.path] = .sha256(scan.digest)
            if file != history {
                if scopeIndex > 0 { inherited += 1 }
                else if owner != cli { historical += 1 }
                let metadata = file.deletingPathExtension().appendingPathExtension("meta.json")
                if FileManager.default.fileExists(atPath: metadata.path) { files[metadata.path] = try fingerprint(metadata) }
            }
            for agent in scan.agents {
                let name = "agent-" + agent + ".jsonl"
                if let match = try candidate(name, owner: owner, scope: scopes[scopeIndex]) {
                    pending.append((match.0, match.1, scopeIndex))
                } else {
                    // Forked rows can still name agents owned by another session, possibly in another project.
                    // Follow the row's original session binding: validated ancestors first, then that session's own transcript.
                    let origins = scan.referenceSessions[agent] ?? []
                    guard origins.count == 1, let origin = origins.compactMap({ $0 }).first else { throw missingAgent }
                    var alternatives: [URL: (String, Int)] = [:]
                    for index in scopes.indices.dropFirst().prefix(inheritedScopes.count) where index > scopeIndex {
                        let scope = scopes[index]
                        guard scope.owners.contains(origin) else { continue }
                        if let match = try candidate(name, owner: origin, scope: scope) {
                            alternatives[match.0] = alternatives[match.0] ?? (match.1, index)
                        }
                    }
                    if alternatives.isEmpty, let index = try binding(origin, agent: agent),
                       let match = try candidate(name, owner: origin, scope: scopes[index]) {
                        alternatives[match.0] = (match.1, index)
                    }
                    guard alternatives.count == 1, let candidate = alternatives.first else {
                        throw missingAgent
                    }
                    pending.append((candidate.key, candidate.value.0, candidate.value.1))
                }
            }
        }
        return (files, seen.count - 1, historical, inherited)
    }

    private static var missingAgent: SwitchError {
        RuntimeLog.validation(.conversationHistory, check: .filePath)
        return .blocked(L10n.tr("This conversation's subagent history is missing or ambiguous. Nothing was transferred."))
    }

    static func fingerprint(_ url: URL) throws -> FileExpectation {
        try SafeFiles.validateAncestors(url)
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) else { return .absent }
        if !directory.boolValue { return .sha256(try hash(url)) }
        var folders: [String] = [], files: [(String, String)] = []
        func visit(_ folder: URL, _ path: String, _ depth: Int) throws {
            guard depth < 32, folders.count + files.count < ConversationResources.maximumFiles else { throw invalid }
            folders.append(path)
            for entry in try SafeFiles.strictChildren(folder) {
                let relative = path + "/" + entry.lastPathComponent
                if try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true { try visit(entry, relative, depth + 1) }
                else {
                    guard folders.count + files.count < ConversationResources.maximumFiles else { throw invalid }
                    files.append((relative, try hash(entry)))
                }
            }
        }
        try visit(url, "resource", 0)
        var result = SHA256()
        for path in folders.sorted() { result.update(data: Data(("d\0" + path + "\0").utf8)) }
        for (path, sha) in files.sorted(by: { $0.0 < $1.0 }) { result.update(data: Data(("f\0" + path + "\0" + sha + "\0").utf8)) }
        return .directory(hex(result.finalize()))
    }

    private static func hash(_ url: URL, consume: ((Data) throws -> Void)? = nil) throws -> String {
        let fd = try SafeFiles.openRead(url), handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let before = try SafeFiles.stamp(fd)
        var result = SHA256(), count: Int64 = 0
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            count += Int64(chunk.count)
            guard count <= before.size else { throw SwitchError.changed }
            result.update(data: chunk)
            try consume?(chunk)
        }
        guard count == before.size, try SafeFiles.stamp(fd) == before else { throw SwitchError.changed }
        return hex(result.finalize())
    }
    private static func hex(_ hash: SHA256.Digest) -> String { hash.map { String(format: "%02x", $0) }.joined() }
    private static var invalid: SwitchError {
        .malformed(L10n.tr("The conversation history could not be verified. Its original data is unchanged."))
    }
}
