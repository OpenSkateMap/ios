import CustomDump
import Testing
@testable import AccountKit

@Suite(.timeLimit(.minutes(1)))
struct NonceTests {
    @Test
    func `the hash is the lowercase hex SHA-256 Apple expects`() {
        // FIPS 180-2 test vector.
        expectNoDifference(Nonce.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test
    func `random nonces are long enough for the API and never repeat`() {
        let nonces = (0..<100).map { _ in Nonce.random() }

        #expect(nonces.allSatisfy { $0.count == 32 })
        expectNoDifference(Set(nonces).count, nonces.count)
    }
}
