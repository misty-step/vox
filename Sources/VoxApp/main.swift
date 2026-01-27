import AppKit

SingleInstanceGuard.acquireOrExit()

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
