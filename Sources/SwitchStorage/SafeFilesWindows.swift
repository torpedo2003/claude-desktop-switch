#if os(Windows)
import Foundation
import SwitchCore
import WinSDK
import ucrt

/// Win32 counterpart of the POSIX primitives. Only drive-letter paths are accepted, and a reparse point
/// (symbolic link, junction or mount point) anywhere on the path is refused.
extension SafeFiles {
    private static let genericRead: DWORD = 0x8000_0000
    private static let genericWrite: DWORD = 0x4000_0000
    private static let appendData: DWORD = 0x0004
    private static let shareRead: DWORD = 0x1
    private static let shareAll: DWORD = 0x7
    private static let createNew: DWORD = 1
    private static let openExisting: DWORD = 3
    private static let openAlways: DWORD = 4
    private static let directory: DWORD = 0x10
    private static let reparsePoint: DWORD = 0x400
    private static let openReparsePoint: DWORD = 0x0020_0000
    private static let invalidAttributes: DWORD = 0xFFFF_FFFF
    private static let notFound: Set<DWORD> = [2, 3]
    private static let replaceExisting: DWORD = 0x1
    private static let writeThrough: DWORD = 0x8
    private static let binary: Int32 = 0x8000

    static func nativePath(_ url: URL) throws -> String {
        guard url.isFileURL, !url.pathComponents.contains("..") else { throw SwitchError.unsafePath }
        var path = url.standardizedFileURL.path.replacingOccurrences(of: "/", with: "\\")
        while path.hasPrefix("\\") { path.removeFirst() }
        while path.count > 3, path.hasSuffix("\\") { path.removeLast() }
        let start = Array(path.unicodeScalars.prefix(3))
        guard start.count == 3, start[0].isASCII, start[0].properties.isAlphabetic, start[1] == ":", start[2] == "\\" else {
            throw SwitchError.unsafePath
        }
        return path
    }

    public static func validateAncestors(_ url: URL) throws {
        let parts = try nativePath(url).split(separator: "\\", omittingEmptySubsequences: true)
        var path = String(parts[0])
        for part in parts.dropFirst() {
            path += "\\" + part
            let (attributes, failure) = path.withCString(encodedAs: UTF16.self) { name -> (DWORD, DWORD) in
                let found = GetFileAttributesW(name)
                return (found, found == invalidAttributes ? GetLastError() : 0)
            }
            if attributes == invalidAttributes {
                if notFound.contains(failure) { return }
                throw SwitchError.unsafePath
            }
            guard attributes & reparsePoint == 0 else { throw SwitchError.unsafePath }
        }
    }

    /// Opens the entry itself, never a link's target, and hands back a C runtime descriptor that owns the handle.
    private static func descriptor(_ url: URL, access: DWORD, share: DWORD, creation: DWORD) throws -> Int32? {
        try validateAncestors(url.deletingLastPathComponent())
        let path = try nativePath(url)
        let opened = path.withCString(encodedAs: UTF16.self) {
            CreateFileW($0, access, share, nil, creation, openReparsePoint, nil)
        }
        guard let handle = opened, handle != INVALID_HANDLE_VALUE else { return nil }
        var information = BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(handle, &information), information.dwFileAttributes & (directory | reparsePoint) == 0 else {
            _ = CloseHandle(handle); throw SwitchError.unsafePath
        }
        let fd = _open_osfhandle(Int(bitPattern: handle), binary)
        guard fd >= 0 else { _ = CloseHandle(handle); throw SwitchError.unsafePath }
        return fd
    }

    public static func openRead(_ url: URL) throws -> Int32 {
        guard let fd = try descriptor(url, access: genericRead, share: shareAll, creation: openExisting) else {
            throw SwitchError.missing(L10n.tr("Could not read the specified local file."))
        }
        return fd
    }

    public static func stamp(_ fd: Int32) throws -> FileStamp {
        var information = BY_HANDLE_FILE_INFORMATION()
        guard let handle = HANDLE(bitPattern: _get_osfhandle(fd)), handle != INVALID_HANDLE_VALUE,
              GetFileInformationByHandle(handle, &information) else { throw SwitchError.unsafePath }
        // FILETIME counts 100 ns ticks from 1601.
        let written = information.ftLastWriteTime
        let ticks = UInt64(written.dwHighDateTime) << 32 | UInt64(written.dwLowDateTime)
        let nanoseconds = Int64(ticks % 10_000_000) * 100
        return FileStamp(inode: UInt64(information.nFileIndexHigh) << 32 | UInt64(information.nFileIndexLow),
                         size: Int64(information.nFileSizeHigh) << 32 | Int64(information.nFileSizeLow),
                         modified: Date(timeIntervalSince1970: Double(ticks / 10_000_000) - 11_644_473_600 + Double(nanoseconds) / 1e9),
                         nanoseconds: nanoseconds)
    }

    /// Folders under the user profile inherit its owner-only access list.
    public static func privateDirectory(_ url: URL) throws {
        try validateAncestors(url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try validateAncestors(url)
    }

    public static func createExclusive(_ url: URL) throws -> Int32 {
        guard let fd = try descriptor(url, access: genericWrite, share: shareRead, creation: createNew) else { throw SwitchError.unsafePath }
        return fd
    }

    public static func openAppend(_ url: URL) throws -> Int32 {
        guard let fd = try descriptor(url, access: appendData, share: shareRead, creation: openAlways) else { throw SwitchError.unsafePath }
        return fd
    }

    public static func temporaryDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(prefix + "-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    public static func atomicWrite(_ data: Data, to url: URL) throws {
        try validateAncestors(url)
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".switch-" + UUID().uuidString + ".tmp")
        guard let fd = try? createExclusive(temporary) else { throw SwitchError.blocked(L10n.tr("Could not create a temporary file.")) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var installed = false
        defer { if !installed { try? FileManager.default.removeItem(at: temporary) } }
        do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
        catch {
            try? handle.close()
            throw SwitchError.blocked(L10n.tr("The write did not finish. The original file is preserved."))
        }
        let source = try nativePath(temporary), target = try nativePath(url)
        let moved = source.withCString(encodedAs: UTF16.self) { source in
            target.withCString(encodedAs: UTF16.self) { MoveFileExW(source, $0, replaceExisting | writeThrough) }
        }
        guard moved else {
            throw SwitchError.blocked(L10n.tr("Could not save changes. Your data is preserved. Check available disk space and try again."))
        }
        installed = true
    }

    /// The write-through rename in `atomicWrite` already reached the disk; a folder has nothing further to flush.
    public static func syncDirectory(_ url: URL) throws {
        try validateAncestors(url)
    }
}
#endif
