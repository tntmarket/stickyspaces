import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Safety contracts (NFR-6, C-9, C-6)")
struct SafetyContractsTests {
    @Test("single-instance launch lock rejects concurrent launcher")
    func singleInstanceLaunchLockRejectsConcurrentLauncher() async {
        let lock = SecondLaunchLock()

        let first = await lock.acquire(ownerID: "launcher-a")
        let second = await lock.acquire(ownerID: "launcher-b")
        await lock.release(ownerID: "launcher-a")
        let third = await lock.acquire(ownerID: "launcher-b")

        #expect(first)
        #expect(second == false)
        #expect(third)
    }

    @Test("local-only guardrail requires no outbound network")
    func localOnlyGuardrailRequiresNoOutboundNetwork() {
        #expect(LocalOnlyGuardrail.requiresOutboundNetwork == false)
        #expect(LocalOnlyGuardrail.allowedTransports == [.unixDomainSocket, .inProcess])
    }

    @Test("default sticky readability contract preserves legibility baseline")
    func defaultStickyReadabilityContractPreservesLegibilityBaseline() {
        let contract = StickyReadabilityContract.defaultContract
        #expect(contract.minimumFontSizePoints >= 14)
        #expect(contract.minimumContrastRatio >= 4.5)
        #expect(contract.hasWindowChrome == false)
        #expect(contract.passesNFR6)
    }
}
