/// A specification is used as a specification to sort and compare strings in the database.
///
/// [See more in the specification](https://github.com/mongodb/specifications/blob/master/source/collation/collation.rst#collation-document-model)
public struct Collation: Codable, Sendable {
    public enum CaseFirstOptions: String, Codable, Sendable {
        /// Similar to lower. [Read more](http://userguide.icu-project.org/collation/customization)
        case off

        /// Sorts lowercased before uppercased characters
        case lower

        /// Sorts uppercased before lowercased characters
        case upper
    }

    /// Defines the level of comparison between two characters
    public enum Strength: Int, Codable, Sendable {
        /// Compares only on base characters, ignoring diadrics and case
        case primary = 1

        /// On top of `primary`, also compares diacritics
        case secondary = 2

        /// On top of `secondary`, also compares case and letter variants
        case tertiary = 3

        /// On top of  `tertiary`, also compares Japanese text
        case quaternary = 4

        case identical = 5
    }

    /// Whether whitespace and punctuation are considered base characters
    public enum Alternate: String, Codable, Sendable {
        /// They're considered as base characters
        case nonIgnorable = "non-ignorable"

        /// Only on Strength level `quaternary` or `identical`
        case shifted
    }

    /// Determines which characters are considered ignorable when the alternate is shifted.
    public enum MaxVariable: String, Codable, Sendable {
        /// Whitespaces and punctuation are ignorable
        case punt

        /// Whitespaces is ignorable
        case space
    }

    /// The ICU locale. Defaults to 'simple' for binary comparison.
    ///
    /// [Supported languages and locales](https://docs.mongodb.com/manual/reference/collation-locales-defaults/#supported-languages-and-locales)
    public var locale: String

    /// If `true`, the text is compared case sensitive
    public var caseLevel: Bool?

    /// Sorts differences on a tertiary level
    public var caseFirst: CaseFirstOptions?

    /// Defines the level of comparison between two characters
    public var strength: Int?

    /// Determines whether to compare numeric strings as nummers or as Strings
    ///
    /// If `true`, `"10" > "2"`
    ///
    /// If `false`, `"10" < "2"`
    public var numericOrdering: Bool?

    /// Whether whitespace and punctuation are considered base characters
    public var alternate: String?

    /// Determines which characters are considered ignorable when the alternate is shifted.
    public var maxVariable: String?

    /// Normalized text into Unicode NFD
    /// [Read on Wikipedia](https://en.wikipedia.org/wiki/Unicode_equivalence#Normalization)
    public var normalization: Bool?

    /// Considers secondary differences in reverse order
    public var backwards: Bool?

    public init(locale: String = "simple") {
        self.locale = locale
    }
}
