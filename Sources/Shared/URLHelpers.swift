import Foundation

extension CharacterSet {
    // RFC 3986 "unreserved" characters only, so a value is safe in any URL position
    // (query values, message:// ids, ical:// event ids).
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}

enum URLDisplay {
    // "https://www.github.com/x" → "github.com"; falls back to the raw string if it has no host.
    static func host(of urlString: String) -> String {
        guard let host = URL(string: urlString)?.host else { return urlString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
