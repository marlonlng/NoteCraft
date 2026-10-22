import AppKit

@MainActor
struct FindPasteboard {
    let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = NSPasteboard(name: .find)) {
        self.pasteboard = pasteboard
    }

    /// The search string shared with other apps through the system find pasteboard.
    var string: String? {
        get { pasteboard.string(forType: .string) }
        nonmutating set {
            pasteboard.clearContents()
            if let newValue {
                pasteboard.setString(newValue, forType: .string)
            }
        }
    }
}

final class WeakReference<Object: AnyObject>: @unchecked Sendable {
    weak var object: Object?

    init(_ object: Object) {
        self.object = object
    }
}
