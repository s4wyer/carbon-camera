import Foundation

/// A small, uncompressed RGGB DNG with known linear values and camera calibration.
/// Generated from numbers; no external photo, embedded JPEG, or license dependency.
enum SyntheticRAWFixture {
    static let levels: [Double] = [0.04, 0.09, 0.18, 0.36, 0.72]
    static let width = 320
    static let height = 128

    static func data(orientation: UInt16 = 1, neutral: [Double] = [1, 1, 1],
                     width: Int = SyntheticRAWFixture.width, height: Int = SyntheticRAWFixture.height) -> Data {
        typealias Entry = (tag: UInt16, type: UInt16, count: UInt32, bytes: Data)
        func short(_ tag: UInt16, _ value: UInt16) -> Entry {
            (tag, 3, 1, words([value]))
        }
        func long(_ tag: UInt16, _ value: UInt32) -> Entry {
            (tag, 4, 1, integers([value]))
        }
        func ascii(_ tag: UInt16, _ value: String) -> Entry {
            let bytes = Data((value + "\0").utf8)
            return (tag, 2, UInt32(bytes.count), bytes)
        }
        func rationals(_ values: [Double]) -> Data {
            integers(values.flatMap { [UInt32(($0 * 1_000_000).rounded()), 1_000_000] })
        }
        // XYZ -> linear sRGB, D65: makes the synthetic camera's RGB primaries
        // equal to sRGB, avoiding dependence on a real camera's spectral response.
        let matrix: [Int32] = [
            324045, -153714, -49853,
            -96927, 187601, 4156,
            5564, -20403, 105723
        ]
        var entries: [Entry] = [
            long(254, 0), long(256, UInt32(width)), long(257, UInt32(height)),
            short(258, 16), short(259, 1), short(262, 32803),
            ascii(271, "Carbon"), ascii(272, "Synthetic Bayer"),
            long(273, 0), short(274, orientation), short(277, 1),
            long(278, UInt32(height)), long(279, UInt32(width * height * 2)),
            short(284, 1),
            (33421, 3, 2, words([2, 2])),
            (33422, 1, 4, Data([0, 1, 1, 2])),
            (50706, 1, 4, Data([1, 3, 0, 0])),
            (50707, 1, 4, Data([1, 1, 0, 0])),
            ascii(50708, "Carbon Synthetic Bayer"),
            (50710, 1, 3, Data([0, 1, 2])), short(50711, 1),
            (50713, 3, 2, words([1, 1])),
            (50714, 5, 1, rationals([0])), long(50717, 65535),
            (50718, 5, 2, rationals([1, 1])), // DefaultScale.
            (50719, 4, 2, integers([0, 0])), // DefaultCropOrigin.
            (50720, 4, 2, integers([UInt32(width), UInt32(height)])), // DefaultCropSize.
            (50721, 10, 9, integers(matrix.flatMap { [UInt32(bitPattern: $0), 100000] })),
            (50728, 5, 3, rationals(neutral)),
            (50730, 10, 1, integers([0, 1])), // BaselineExposure = zero EV.
            short(50778, 21), // CalibrationIlluminant1 = D65.
            (50829, 4, 4, integers([0, 0, UInt32(height), UInt32(width)])) // ActiveArea.
        ]
        entries.sort { $0.tag < $1.tag }
        let payloadStart = 8 + 2 + entries.count * 12 + 4
        let pixelStart = payloadStart + entries.reduce(0) {
            $0 + ($1.bytes.count > 4 ? (($1.bytes.count + 1) / 2) * 2 : 0)
        }
        var table = Data()
        var payload = Data()
        for entry in entries {
            table.append(words([entry.tag, entry.type]))
            table.append(integers([entry.count]))
            if entry.tag == 273 {
                table.append(integers([UInt32(pixelStart)]))
            } else if entry.bytes.count <= 4 {
                table.append(entry.bytes)
                table.append(Data(repeating: 0, count: 4 - entry.bytes.count))
            } else {
                table.append(integers([UInt32(payloadStart + payload.count)]))
                payload.append(entry.bytes)
                if payload.count % 2 != 0 { payload.append(0) }
            }
        }
        var result = Data([0x49, 0x49, 42, 0, 8, 0, 0, 0])
        result.append(words([UInt16(entries.count)]))
        result.append(table)
        result.append(integers([0])) // No following IFD (no processed preview).
        result.append(payload)
        let cfa = [0, 1, 1, 2]
        for y in 0..<height {
            for x in 0..<width {
                let level = levels[x / (width / levels.count)]
                let channel = cfa[(y % 2) * 2 + x % 2]
                let sample = UInt16((level * neutral[channel] * 65535).rounded())
                result.append(words([sample]))
            }
        }
        return result
    }

    private static func words(_ values: [UInt16]) -> Data {
        Data(values.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] })
    }

    private static func integers(_ values: [UInt32]) -> Data {
        Data(values.flatMap { value in
            (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
        })
    }
}
