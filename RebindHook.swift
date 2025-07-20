struct RebindHook {
    let name: String
    let replace: UnsafeMutableRawPointer
    let orig: UnsafeMutablePointer<UnsafeMutableRawPointer?>
}
