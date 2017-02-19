//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import Foundation

/// Reads a `String` into hours, minutes and seconds
private func parseTimestamp(_ timestamp: String) -> (hours: Int, minutes: Int, seconds: Int, used: Int)? {
    var index = 0
    let maxIndex = timestamp.characters.count
    
    // We always at least have minutes and hours
    guard maxIndex >= 4 else {
        return nil
    }
    
    guard let hours = Int(timestamp[index..<index+2]) else {
        return nil
    }
    
    index += 2
    
    // If there's a semicolon, advance
    if timestamp[index] == ":" && index + 3 <= maxIndex {
        index += 1
    }
    
    guard let minutes = Int(timestamp[index..<index+2]) else {
        return nil
    }
    
    index += 2
    var seconds = 0
    
    // If there are seconds
    if maxIndex >= index + 2 {
        // If there's a semicolon, advance
        if timestamp[index] == ":" {
            index += 1
        }
        
        // If there are still two characters left (in the case of a colon), try to parse it into an `Int` for seconds
        guard maxIndex >= index + 2, let s = Int(timestamp[index..<index+2]) else {
            return nil
        }
        
        seconds = s
        
        index += 2
    }
    
    return (hours, minutes, seconds, index)
}

/// Parses a timestamp (not date) from a `String` including timezones
private func parseTime(from string: String) -> Time? {
    var index = 0
    let maxIndex = string.characters.count
    
    guard let result = parseTimestamp(string) else {
        return nil
    }
    
    index += result.used
    let hours = result.hours
    let minutes = result.minutes
    let seconds = result.seconds
    
    var offsetHours = 0
    var offsetMinutes = 0
    var offsetSeconds = 0
    
    // If there's a timezone marker
    if maxIndex >= index + 3 && (string[index] == "+" || string[index] == "-" || string[index] == "Z") {
        switch string[index] {
        case "+":
            index += 1
            
            guard let offsetResult = parseTimestamp(string[index..<maxIndex]) else {
                return nil
            }
            
            index += offsetResult.used
            
            // Subtract from epoch time, since we're ahead of UTC
            offsetHours = -(offsetResult.hours)
            offsetMinutes = -(offsetResult.minutes)
            offsetSeconds = -(offsetResult.seconds)
        case "-":
            index += 1
            guard let offsetResult = parseTimestamp(string[index..<maxIndex]) else {
                return nil
            }
            
            index += offsetResult.used
            
            // Add to epoch time, since we're behind of UTC
            offsetHours = offsetResult.hours
            offsetMinutes = offsetResult.minutes
            offsetSeconds = offsetResult.seconds
        case "Z":
            break
        default:
            return nil
        }
    }
    
    return (hours, minutes, seconds, offsetHours, offsetMinutes, offsetSeconds)
}

/// Parses an ISO8601 string into a `Date` object
///
/// TODO: Doesn't work with weeks yet
///
/// TODO: Doesn't work with empty years yet (except 2016)!
///
/// TODO: Doesn't work with yeardays, only months
internal func parseISO8601(from string: String) -> Date? {
    let year: Int
    let maxIndex = string.characters.count - 1
    
    var index = 0
    
    if string[0] == "-" {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy"
        
        guard let yyyy = Int(fmt.string(from: Date())) else {
            return nil
        }
        
        year = yyyy
        
        index += 1
    } else if string.characters.count >= 4 {
        guard let tmpYear = Int(string[0..<4]) else {
            return nil
        }
        
        year = tmpYear
        index += 4
    } else {
        return nil
    }
    
    guard index <= maxIndex else {
        return nil
    }
    
    if string[index] == "-" {
        index += 1
    }
    
    if string[index] == "W" {
        // parse week
    } else {
        // parse yearday too, not just months
        
        guard index + 2 <= maxIndex else {
            return nil
        }
        
        guard let month = Int(string[index..<index + 2]) else {
            return nil
        }
        
        index += 2
        
        guard index <= maxIndex else {
            return date(year: year, month: month)
        }
        
        if string[index] == "-" {
            index += 1
        }
        
        guard index <= maxIndex else {
            return date(year: year, month: month)
        }
        
        let day: Int
        
        if index + 1 > maxIndex {
            guard let d = Int(string[index..<index + 1]) else {
                return nil
            }
            
            day = d
            
            return date(year: year, month: month, day: day)
        } else if index + 2 > maxIndex {
            guard let d = Int(string[index..<index + 2]) else {
                return nil
            }
            
            day = d
            
            return date(year: year, month: month, day: day)
        } else if string[index + 1] == "T" {
            guard let d = Int(string[index..<index + 1]) else {
                return nil
            }
            
            day = d
            index += 2
            
            return date(year: year, month: month, day: day, time: parseTime(from: string[index..<maxIndex]))
        } else if string[index + 2] == "T" {
            guard let d = Int(string[index..<index + 2]) else {
                return nil
            }
            
            day = d
            index += 3
            
            return date(year: year, month: month, day: day, time: parseTime(from: string[index..<maxIndex + 1]))
        } else {
            return nil
        }
    }
    
    return nil
}


typealias Time = (hours: Int, minutes: Int, seconds: Int, offsetHours: Int, offsetMinutes: Int, offsetSeconds: Int)

/// Calculates the amount of passed days
private func totalDays(inMonth month: Int, forYear year: Int, currentDay day: Int) -> Int {
    // Subtract one day. The provided day is not the amount of days that have passed, it's the current day
    var days = day - 1
    
    // Add leap day for months beyond 2
    if year % 4 == 0 {
        days += 1
    }
    
    switch month {
    case 1:
        return 0 + day - 1
    case 2:
        return 31 + day - 1
    case 3:
        return days + 59
    case 4:
        return days + 90
    case 5:
        return days + 120
    case 6:
        return days + 151
    case 7:
        return days + 181
    case 8:
        return days + 212
    case 9:
        return days + 243
    case 10:
        return days + 273
    case 11:
        return days + 304
    default:
        return days + 334
    }
}

/// Calculates epoch date from provided time information
private func date(year: Int, month: Int, day: Int? = nil, time: Time? = nil) -> Date {
    let seconds = (time?.seconds ?? 0) - (time?.offsetSeconds ?? 0)
    let minutes = (time?.minutes ?? 0) - (time?.offsetMinutes ?? 0)
    
    // Remove one hours, to indicate the hours that passed this day
    // Not the current hour
    let hours = (time?.hours ?? 0) + (time?.offsetHours ?? 0)
    let day = day ?? 0
    let yearDay = totalDays(inMonth: month, forYear: year, currentDay: day)
    let year = year - 1900
    
    let epoch = seconds + minutes*60 + hours*3600 + yearDay*86400 +
        (year-70)*31536000 + ((year-69)/4)*86400 -
        ((year-1)/100)*86400 + ((year+299)/400)*86400
    return Date(timeIntervalSince1970: Double(epoch))
}

// MARK - String helpers
private extension String {
    subscript(_ i: Int) -> String {
        get {
            let index = self.characters.index(self.characters.startIndex, offsetBy: i)
            return String(self.characters[index])
        }
    }
    subscript(_ i: CountableRange<Int>) -> String {
        get {
            var result = ""
            
            for j in i {
                let index = self.characters.index(self.characters.startIndex, offsetBy: j)
                result += String(self.characters[index])
            }
            
            return result
        }
    }
}
