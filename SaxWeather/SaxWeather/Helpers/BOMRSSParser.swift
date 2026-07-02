
import Foundation

/// Parses BOM RSS/XML alert feeds without a third-party dependency.
enum BOMRSSParser {

    static func parseItems(from data: Data) throws -> [RSSItem] {
        let parser = Parser(data: data)
        return parser.parse()
    }

    private final class Parser: NSObject, XMLParserDelegate {
        private let parser: XMLParser
        private var items: [RSSItem] = []
        private var currentItem: PartialItem?
        private var currentElement = ""
        private var currentText = ""

        init(data: Data) {
            self.parser = XMLParser(data: data)
            super.init()
            parser.delegate = self
        }

        func parse() -> [RSSItem] {
            parser.parse()
            return items
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            currentElement = elementName
            currentText = ""
            if elementName == "item" {
                currentItem = PartialItem()
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if elementName == "item" {
                if let item = currentItem?.build() {
                    items.append(item)
                }
                currentItem = nil
                currentText = ""
                return
            }

            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }

            switch elementName {
            case "title":
                currentItem?.title = value
            case "description":
                currentItem?.description = value
            case "pubDate":
                currentItem?.pubDate = value
            case "link":
                currentItem?.link = value
            case "guid":
                currentItem?.guid = value
            default:
                break
            }

            currentText = ""
        }
    }

    private struct PartialItem {
        var title: String?
        var description: String?
        var link: String?
        var pubDate: String?
        var guid: String?

        func build() -> RSSItem? {
            RSSItem(
                title: title,
                description: description,
                link: link,
                pubDate: pubDate,
                guid: guid
            )
        }
    }
}
