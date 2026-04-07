import Foundation
import AppKit

class AirDropService {
    static let shared = AirDropService()
    func shareFileViaAirDrop(fileURL: URL) {
        let service = NSSharingService(named: .sendViaAirDrop)
        let items: [Any] = [fileURL]
        if let service = service, service.canPerform(withItems: items) {
            service.perform(withItems: items)
        }
    }
}
