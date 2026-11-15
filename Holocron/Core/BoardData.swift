import Foundation

// MARK: - Welcome board helpers
//
// The parts of the Class screen's Welcome board that need only Foundation: the icons worked out from a
// subject or item name, the weather forecast and how it is read, and the "Copy the last list" rule.
// Kept apart from the views so they can be checked on their own with swiftc.

enum BoardIcons {
    /// Icons the teacher can choose for a subject, in the order the menu shows them.
    static let choices: [(name: String, label: String)] = [
        ("sun.max", "Sun"), ("book", "Book"), ("books.vertical", "Books"), ("pencil", "Pencil"),
        ("textformat.abc", "Letters"), ("divide", "Divide"), ("number", "Number"), ("function", "Function"),
        ("flask", "Flask"), ("leaf", "Leaf"), ("globe.asia.australia", "Globe"), ("magnifyingglass", "Magnifying glass"),
        ("figure.run", "Running"), ("sportscourt", "Sports court"), ("paintpalette", "Palette"), ("music.note", "Music"),
        ("theatermasks", "Drama"), ("character.bubble", "Language"), ("desktopcomputer", "Computer"), ("gearshape.2", "Gears"),
        ("cross", "Cross"), ("heart", "Heart"), ("person.3", "Group"), ("bubble.left.and.bubble.right", "Talk"),
        ("fork.knife", "Eating"), ("megaphone", "Assembly"), ("star", "Star"), ("house", "Home"),
    ]

    /// The icon for a subject or block name, worked out from words in it. "" for a period name with no match.
    static func guess(_ name: String) -> String {
        let rules: [([String], String)] = [
            (["morning", "org", "roll"], "sun.max"),
            (["eating", "recess", "lunch", "snack"], "fork.knife"),
            (["devotion", "chapel", "religion", "re", "christian", "prayer", "mass"], "cross"),
            (["circle", "wellbeing", "respectful", "sel"], "heart"),
            (["spelling", "phonics", "word"], "textformat.abc"),
            (["library"], "books.vertical"),
            (["writing", "handwriting"], "pencil"),
            (["literacy", "reading", "english", "book"], "book"),
            (["math", "numeracy", "number"], "divide"),
            (["science", "stem", "steam"], "flask"),
            (["tdl", "inquiry", "uoi", "geography", "history", "humanities", "hass"], "magnifyingglass"),
            (["pe", "sport", "physical", "fitness", "swimming"], "figure.run"),
            (["art", "visual"], "paintpalette"),
            (["music", "band", "choir"], "music.note"),
            (["drama", "performing"], "theatermasks"),
            (["french", "italian", "japanese", "indonesian", "chinese", "mandarin", "language", "lote", "spanish", "german"], "character.bubble"),
            (["digital", "ict", "computer", "coding", "tech"], "desktopcomputer"),
            (["assembly"], "megaphone"),
            (["garden", "kitchen"], "leaf"),
        ]
        return firstMatch(name, rules) ?? ""
    }

    /// The symbol of the first rule with a word in `name`. A rule word of four letters or more also matches the
    /// start of a word (math matches Maths); shorter ones must be the whole word, so "art" never matches "start".
    static func firstMatch(_ name: String, _ rules: [([String], String)]) -> String? {
        let tokens = name.lowercased().replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        for (words, symbol) in rules {
            for w in words where tokens.contains(where: { $0 == w || (w.count >= 4 && $0.hasPrefix(w)) }) {
                return symbol
            }
        }
        return nil
    }

    /// The icon for something the class needs, from words in it.
    static func need(_ item: String) -> String {
        let rules: [([String], String)] = [
            (["water", "bottle", "drink"], "waterbottle"),
            (["hat", "hats", "sunscreen"], "sun.max"),
            (["pencil", "pen", "pens", "case"], "pencil"),
            (["maths", "math"], "divide"),
            (["reading", "book", "diary", "journal"], "book.closed"),
            (["library"], "books.vertical"),
            (["bag", "backpack"], "backpack"),
            (["device", "laptop", "ipad", "computer", "chromebook"], "laptopcomputer"),
            (["headphone", "earphone"], "headphones"),
            (["uniform", "jumper", "shirt", "clothes", "smock"], "tshirt"),
            (["sport", "runners", "shoes", "pe"], "figure.run"),
            (["instrument", "music", "recorder"], "music.note"),
            (["art"], "paintpalette"),
            (["note", "form", "permission", "money"], "envelope"),
            (["lunch", "snack", "fruit"], "fork.knife"),
        ]
        return firstMatch(item, rules) ?? "checkmark.circle"
    }

    /// Things most classes need, offered when the day's list is empty.
    static let suggestedNeeds = ["Writing book", "Pencil case", "Reading book", "Maths book",
                                 "Water bottle", "Library bag", "Hat", "Device"]

    /// The SF Symbol for a file, by its extension.
    static func file(_ ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.richtext"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle"
        case "doc", "docx", "pages", "rtf", "txt", "md": return "doc.text"
        case "xls", "xlsx", "numbers", "csv": return "tablecells"
        case "jpg", "jpeg", "png", "heic", "gif", "tif", "tiff", "webp": return "photo"
        case "mov", "mp4", "m4v": return "film"
        case "mp3", "m4a", "wav", "aiff": return "waveform"
        case "webloc", "url": return "link"
        default: return "doc"
        }
    }
}

// MARK: - What you need today

enum NeedsList {
    /// The items for "Copy the last list": those on the most recent earlier date that has any.
    static func lastList(before date: String, in rows: [[String: String]]) -> [String] {
        let earlier = rows.filter { ($0["date"] ?? "") < date && !($0["item"] ?? "").isEmpty }
        guard let last = earlier.map({ $0["date"] ?? "" }).max() else { return [] }
        return earlier.filter { $0["date"] == last }.compactMap { $0["item"] }
    }
}

// MARK: - Weather

/// One day of the forecast.
struct WeatherDay: Equatable {
    var date: String
    var code: Int
    var high: Double
    var low: Double
    /// Chance of rain, 0 to 100.
    var rain: Int
    var uv: Double

    /// SunSmart: hats and sunscreen when the UV index reaches 3.
    var sunSmart: Bool { uv >= 3 }
}

/// A town found by name.
struct WeatherPlace: Equatable {
    var name: String
    var region: String
    var latitude: Double
    var longitude: Double
}

/// The forecast comes from Open-Meteo, which needs no account or key. Only the town's latitude and longitude
/// are sent, rounded to two places (about a kilometre). The town name is sent once, to look it up, when the
/// teacher types it. Nothing about students is ever sent.
enum WeatherService {
    static let forecastHost = "api.open-meteo.com"
    static let placeHost = "geocoding-api.open-meteo.com"

    static func forecastURL(latitude: Double, longitude: Double) -> URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = forecastHost
        c.path = "/v1/forecast"
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "8"),
        ]
        return c.url
    }

    static func placeURL(_ name: String) -> URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = placeHost
        c.path = "/v1/search"
        c.queryItems = [
            URLQueryItem(name: "name", value: name.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "countryCode", value: "AU"),
        ]
        return c.url
    }

    private struct ForecastJSON: Decodable {
        struct Daily: Decodable {
            var time: [String]
            var weather_code: [Int?]
            var temperature_2m_max: [Double?]
            var temperature_2m_min: [Double?]
            var precipitation_probability_max: [Int?]?
            var uv_index_max: [Double?]?
        }
        var daily: Daily
    }

    private struct PlaceJSON: Decodable {
        struct Result: Decodable {
            var name: String
            var latitude: Double
            var longitude: Double
            var admin1: String?
        }
        var results: [Result]?
    }

    /// The days in a forecast answer. Days with a missing temperature are left out.
    static func parseForecast(_ data: Data) -> [WeatherDay] {
        guard let f = try? JSONDecoder().decode(ForecastJSON.self, from: data) else { return [] }
        let d = f.daily
        return d.time.indices.compactMap { i in
            guard i < d.temperature_2m_max.count, i < d.temperature_2m_min.count,
                  let hi = d.temperature_2m_max[i], let lo = d.temperature_2m_min[i] else { return nil }
            let code = i < d.weather_code.count ? d.weather_code[i] ?? 0 : 0
            let rain = d.precipitation_probability_max.flatMap { i < $0.count ? $0[i] : nil } ?? 0
            let uv = d.uv_index_max.flatMap { i < $0.count ? $0[i] : nil } ?? 0
            return WeatherDay(date: d.time[i], code: code, high: hi, low: lo, rain: rain, uv: uv)
        }
    }

    static func parsePlace(_ data: Data) -> WeatherPlace? {
        guard let p = try? JSONDecoder().decode(PlaceJSON.self, from: data), let r = p.results?.first else { return nil }
        return WeatherPlace(name: r.name, region: r.admin1 ?? "", latitude: r.latitude, longitude: r.longitude)
    }

    /// The forecast from today on, school days only (Monday to Friday), up to `count` days.
    static func schoolDays(_ days: [WeatherDay], from today: String, count: Int = 5) -> [WeatherDay] {
        Array(days.filter { $0.date >= today && dayIdx($0.date) < 5 }.prefix(count))
    }

    /// An SF Symbol for a WMO weather code.
    static func symbol(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81: return "cloud.rain.fill"
        case 65, 67, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// A word or two for a WMO weather code.
    static func words(_ code: Int) -> String {
        switch code {
        case 0: return "Sunny"
        case 1: return "Mostly sunny"
        case 2: return "Partly cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 66, 80, 81: return "Showers"
        case 65, 67, 82: return "Heavy rain"
        case 71, 73, 75, 77, 85, 86: return "Snow"
        case 95, 96, 99: return "Storms"
        default: return "Cloudy"
        }
    }
}
