import CoreGraphics
import Foundation
import ImageIO
import Vision

// Validation-only macOS tool. Inspect content rather than PNG byte size: a
// legitimate compact detail page can compress smaller than a launch frame.
guard CommandLine.arguments.count == 2 else { exit(2) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { exit(2) }

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["zh-Hans", "en-US"]
request.usesLanguageCorrection = false
// Exclude status-bar text and the home indicator from blank-frame detection.
request.regionOfInterest = CGRect(x: 0, y: 0.08, width: 1, height: 0.84)
do {
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let regions = (request.results ?? []).filter {
        ($0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) >= 2
    }.count
    print("Screenshot content regions: \(regions)")
    exit(regions >= 2 ? 0 : 1)
} catch {
    print("Screenshot content validation failed: \(error)")
    exit(2)
}
