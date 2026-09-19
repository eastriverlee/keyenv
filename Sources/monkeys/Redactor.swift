#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct SpentValue {
    let name: String
    let value: String
}

struct Redactor {
    private struct Secret {
        let bytes: [UInt8]
        let marker: [UInt8]
        let shifts: [Int]

        init(bytes: [UInt8], marker: [UInt8]) {
            self.bytes = bytes
            self.marker = marker
            var shifts = [Int](repeating: bytes.count, count: 256)
            for (index, byte) in bytes.dropLast().enumerated() { shifts[Int(byte)] = bytes.count - 1 - index }
            self.shifts = shifts
        }
    }

    private let secrets: [Secret]
    private let longest: Int
    private let showsPlaceholders: Bool
    private var work: [UInt8] = []
    private var held: [UInt8] = []

    init(_ values: [SpentValue], showsPlaceholders: Bool) {
        self.showsPlaceholders = showsPlaceholders
        secrets = values
            .filter { !$0.value.isEmpty }
            .map { Secret(bytes: Array($0.value.utf8), marker: Array("[redacted \($0.name)]".utf8)) }
            .sorted { $0.bytes.count > $1.bytes.count }
        longest = secrets.first?.bytes.count ?? 0
        work.reserveCapacity(65536 + longest)
    }

    mutating func scan(_ chunk: UnsafeRawBufferPointer, into output: inout [UInt8]) {
        guard !secrets.isEmpty else {
            output.append(contentsOf: chunk)
            return
        }
        work.removeAll(keepingCapacity: true)
        work.append(contentsOf: held)
        work.append(contentsOf: chunk)
        retractPlaceholders(into: &output)

        var emitted = 0
        while let (position, secret) = earliestMatch(from: emitted) {
            output.append(contentsOf: work[emitted..<position])
            output.append(contentsOf: secret.marker)
            emitted = position + secret.bytes.count
        }
        let holdback = holdbackLength(from: emitted)
        output.append(contentsOf: work[emitted..<(work.count - holdback)])
        held.append(contentsOf: work[(work.count - holdback)...])
        if showsPlaceholders { output.append(contentsOf: repeatElement(UInt8(ascii: "*"), count: holdback)) }
    }

    mutating func flush(into output: inout [UInt8]) {
        retractPlaceholders(into: &output)
        output.append(contentsOf: held)
    }

    private mutating func retractPlaceholders(into output: inout [UInt8]) {
        if showsPlaceholders { output.append(contentsOf: repeatElement(UInt8(ascii: "\u{8}"), count: held.count)) }
        held.removeAll(keepingCapacity: true)
    }

    private func earliestMatch(from start: Int) -> (Int, Secret)? {
        var best: (Int, Secret)?
        for secret in secrets {
            guard let position = firstOccurrence(of: secret, from: start, before: best?.0) else { continue }
            best = (position, secret)
        }
        return best
    }

    private func firstOccurrence(of secret: Secret, from start: Int, before limit: Int?) -> Int? {
        let end = min(limit ?? work.count, work.count)
        let length = secret.bytes.count
        guard length <= end - start else { return nil }
        return work.withUnsafeBufferPointer { haystack -> Int? in
            secret.bytes.withUnsafeBufferPointer { pattern -> Int? in
                let lastByte = pattern[length - 1]
                var position = start
                while position <= end - length {
                    let windowEnd = haystack[position + length - 1]
                    if windowEnd == lastByte, memcmp(haystack.baseAddress! + position, pattern.baseAddress!, length) == 0 {
                        return position
                    }
                    position += secret.shifts[Int(windowEnd)]
                }
                return nil
            }
        }
    }

    private func holdbackLength(from emitted: Int) -> Int {
        let available = work.count - emitted
        var longestPrefix = 0
        for secret in secrets {
            var length = min(secret.bytes.count - 1, available)
            while length > longestPrefix {
                if work[(work.count - length)...].elementsEqual(secret.bytes[..<length]) {
                    longestPrefix = length
                    break
                }
                length -= 1
            }
        }
        return longestPrefix
    }
}
