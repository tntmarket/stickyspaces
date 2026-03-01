import Foundation

public actor SecondLaunchLock {
    private var ownerID: String?

    public init() {}

    public func acquire(ownerID: String) -> Bool {
        if let currentOwner = self.ownerID, currentOwner != ownerID {
            return false
        }
        self.ownerID = ownerID
        return true
    }

    public func release(ownerID: String) {
        guard self.ownerID == ownerID else {
            return
        }
        self.ownerID = nil
    }
}
