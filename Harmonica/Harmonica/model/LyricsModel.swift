import Foundation

struct LyricLine {
    let text: String
    let timings: [Double]
    
    var characterDurations: [(String, Double)] {
        let chars = Array(text).map { String($0) }
        guard timings.count > 1 else { return [] }
        
        let durations = zip(timings, timings.dropFirst()).map { $1 - $0 }
        let result = Array(zip(chars, durations))
        
        // 문자 수와 duration 수가 맞지 않으면 빈 배열 반환
        guard result.count <= chars.count else { return [] }
        
        return result
    }
}

struct LyricSegment {
    let startTime: Double
    var endTime: Double = 0
    let lyric: String
    let timingArray: [Double]
    let index: Int
}

struct LyricData: Codable {
    let index: Int
    let Lyric: String // mp3Start + duration
    let timingArray: [Double]
    let mp3Start: Double
    let duration: Double?
}

enum PlayMode {
    case ar
    case mr
}

