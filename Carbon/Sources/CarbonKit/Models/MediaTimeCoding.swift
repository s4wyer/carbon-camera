import CoreMedia

// CMTime does not conform to Codable. Preserve all four components in our
// contracts without adding a retroactive conformance to an SDK type.
extension KeyedEncodingContainer {
    mutating func encode(_ time: CMTime, forKey key: Key) throws {
        var container = nestedContainer(keyedBy: MediaTimeKey.self, forKey: key)
        try container.encode(time.value, forKey: .value)
        try container.encode(time.timescale, forKey: .timescale)
        try container.encode(time.flags.rawValue, forKey: .flags)
        try container.encode(time.epoch, forKey: .epoch)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: CMTime.Type, forKey key: Key) throws -> CMTime {
        let container = try nestedContainer(keyedBy: MediaTimeKey.self, forKey: key)
        return CMTime(
            value: try container.decode(Int64.self, forKey: .value),
            timescale: try container.decode(Int32.self, forKey: .timescale),
            flags: CMTimeFlags(rawValue: try container.decode(UInt32.self, forKey: .flags)),
            epoch: try container.decode(Int64.self, forKey: .epoch)
        )
    }
}

private enum MediaTimeKey: String, CodingKey {
    case value, timescale, flags, epoch
}
