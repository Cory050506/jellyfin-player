import Foundation

@inline(__always)
func npLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
