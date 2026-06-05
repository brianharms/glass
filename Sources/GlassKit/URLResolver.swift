import Foundation

public enum URLResolver {
    public enum Resolved {
        case web(URL)
        case file(URL)
    }

    public static func resolve(_ input: String) -> Resolved? {
        guard !input.isEmpty else { return nil }

        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            guard let url = URL(string: input) else { return nil }
            return .web(url)
        }

        let path: String
        if input.hasPrefix("/") || input.hasPrefix("~") {
            path = NSString(string: input).expandingTildeInPath
        } else {
            path = FileManager.default.currentDirectoryPath + "/" + input
        }

        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return .file(URL(fileURLWithPath: path))
    }
}
