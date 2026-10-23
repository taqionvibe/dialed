// Asks a running Dialed (with EnableDebugHooks) to render its windows to PNGs.
// Usage: swift scripts/render-screenshots.swift <output-dir>
import Foundation
let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath + "/build/shots"
DistributedNotificationCenter.default().postNotificationName(.init("io.github.taqionvibe.dialed.render"),
                                                             object: (dir as NSString).standardizingPath, userInfo: nil, deliverImmediately: true)
print("Requested screenshots in \(dir)")
