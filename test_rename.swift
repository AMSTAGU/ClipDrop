import Foundation

let fm = FileManager.default
let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first!
let textURL = downloads.appendingPathComponent("Text.txt")
let targetURL = downloads.appendingPathComponent("Text.aidrop_temp")

// simulate sharingd writing a file
try! "Hello".write(to: textURL, atomically: true, encoding: .utf8)

// instantly rename
try? fm.moveItem(at: textURL, to: targetURL)

// try reading
do {
    let text = try String(contentsOf: targetURL, encoding: .utf8)
    print("Read text: \(text)")
} catch {
    print("Failed to read: \(error)")
}
