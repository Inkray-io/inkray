#[test_only]
module contracts::mock_blob {

    /// A mock Blob for testing purposes. It has `store` and `drop` abilities,
    /// unlike the real `walrus::blob::Blob`, which makes it usable in test scenarios.
    public struct MockBlob has store, drop {
        blob_id: u256,
        size: u64,
        encoding_type: u8,
    }

    // === Public Functions ===

    /// Create a new mock blob for testing.
    public fun new(blob_id: u256, size: u64, _ctx: &mut TxContext): MockBlob {
        MockBlob {
            blob_id,
            size,
            encoding_type: 0, // Default value, can be extended if needed
        }
    }

    /// Get the blob ID.
    public fun blob_id(blob: &MockBlob): u256 {
        blob.blob_id
    }

    /// Get the blob size.
    public fun size(blob: &MockBlob): u64 {
        blob.size
    }
}
