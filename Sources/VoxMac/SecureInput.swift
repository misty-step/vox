import Carbon
import Foundation

public enum SecureInput {
    public static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
