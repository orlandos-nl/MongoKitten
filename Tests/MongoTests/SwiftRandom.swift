//
//  SwiftRandom.swift
//
//  Created by Furkan Yilmaz on 7/10/15.
//  Copyright (c) 2015 Furkan Yilmaz. All rights reserved.
//

import Foundation

// each type has its own random

public extension Bool {
    /// SwiftRandom extension
    public static func random() -> Bool {
        return Int.random() % 2 == 0
    }
}

public extension Int {
    /// SwiftRandom extension
    public static func random(range: Range<Int>) -> Int {
        return range.startIndex + Int(arc4random_uniform(UInt32(range.endIndex - range.startIndex)))
    }
    
    /// SwiftRandom extension
    public static func random(lower: Int = 0, _ upper: Int = 100) -> Int {
        return lower + Int(arc4random_uniform(UInt32(upper - lower + 1)))
    }
}

public extension Double {
    /// SwiftRandom extension
    public static func random(lower: Double = 0, _ upper: Double = 100) -> Double {
        return (Double(arc4random()) / 0xFFFFFFFF) * (upper - lower) + lower
    }
}

public extension Float {
    /// SwiftRandom extension
    public static func random(lower: Float = 0, _ upper: Float = 100) -> Float {
        return (Float(arc4random()) / 0xFFFFFFFF) * (upper - lower) + lower
    }
}

public extension CGFloat {
    /// SwiftRandom extension
    public static func random(lower: CGFloat = 0, _ upper: CGFloat = 1) -> CGFloat {
        return CGFloat(Float(arc4random()) / Float(UINT32_MAX)) * (upper - lower) + lower
    }
}

public extension NSDate {
    /// SwiftRandom extension
    public static func randomWithinDaysBeforeToday(days: Int) -> NSDate {
        let today = NSDate()
        
        guard let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian) else {
            print("no calendar \"NSCalendarIdentifierGregorian\" found")
            return today
        }
        
        let r1 = arc4random_uniform(UInt32(days))
        let r2 = arc4random_uniform(UInt32(23))
        let r3 = arc4random_uniform(UInt32(23))
        let r4 = arc4random_uniform(UInt32(23))
        
        let offsetComponents = NSDateComponents()
        offsetComponents.day = Int(r1) * -1
        offsetComponents.hour = Int(r2)
        offsetComponents.minute = Int(r3)
        offsetComponents.second = Int(r4)
        
        guard let rndDate1 = gregorian.date(byAdding: offsetComponents, to: today, options: []) else {
            print("randoming failed")
            return today
        }
        return rndDate1
    }
    
    /// SwiftRandom extension
    public static func random() -> NSDate {
        let randomTime = NSTimeInterval(arc4random_uniform(UInt32.max))
        return NSDate(timeIntervalSince1970: randomTime)
    }
    
}

public extension Array {
    /// SwiftRandom extension
    public func randomItem() -> Element {
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }
}

public extension ArraySlice {
    /// SwiftRandom extension
    public func randomItem() -> Element {
        let index = Int.random(self.startIndex..<self.endIndex)
        return self[index]
    }
}

public extension NSURL {
    /// SwiftRandom extension
    public static func random() -> NSURL {
        let urlList = ["http://www.google.com", "http://leagueoflegends.com/", "https://github.com/", "http://stackoverflow.com/", "https://medium.com/", "http://9gag.com/gag/6715049", "http://imgur.com/gallery/s9zoqs9", "https://www.youtube.com/watch?v=uelHwf8o7_U"]
        return NSURL(string: urlList.randomItem())!
    }
}


public struct Randoms {
    
    //==========================================================================================================
    // MARK: - Object randoms
    //==========================================================================================================
    
    public static func randomBool() -> Bool {
        return Bool.random()
    }
    
    public static func randomInt(range: Range<Int>) -> Int {
        return Int.random(range.startIndex, range.endIndex)
    }
    
    public static func randomInt(lower: Int = 0, _ upper: Int = 100) -> Int {
        return Int.random(lower, upper)
    }
    
    public static func randomPercentageisOver(percentage: Int) -> Bool {
        return Int.random() > percentage
    }
    
    public static func randomDouble(lower: Double = 0, _ upper: Double = 100) -> Double {
        return Double.random(lower, upper)
    }
    
    public static func randomFloat(lower: Float = 0, _ upper: Float = 100) -> Float {
        return Float.random(lower, upper)
    }
    
    public static func randomCGFloat(lower: CGFloat = 0, _ upper: CGFloat = 1) -> CGFloat {
        return CGFloat.random(lower, upper)
    }
    
    public static func randomDateWithinDaysBeforeToday(days: Int) -> NSDate {
        return NSDate.randomWithinDaysBeforeToday(days)
    }
    
    public static func randomDate() -> NSDate {
        return NSDate.random()
    }
    
    public static func randomNSURL() -> NSURL {
        return NSURL.random()
    }
    
    //==========================================================================================================
    // MARK: - Fake random data generators
    //==========================================================================================================
    
    public static func randomFakeName() -> String {
        let firstNameList = ["Henry", "William", "Geoffrey", "Jim", "Yvonne", "Jamie", "Leticia", "Priscilla", "Sidney", "Nancy", "Edmund", "Bill", "Megan"]
        let lastNameList = ["Pearson", "Adams", "Cole", "Francis", "Andrews", "Casey", "Gross", "Lane", "Thomas", "Patrick", "Strickland", "Nicolas", "Freeman"]
        return firstNameList.randomItem() + " " + lastNameList.randomItem()
    }
    
    public static func randomFakeGender() -> String {
        return Bool.random() ? "Male" : "Female"
    }
    
    public static func randomFakeConversation() -> String {
        let convoList = ["You embarrassed me this evening.","You don't think that was just lemonade in your glass, do you?","Do you ever think we should just stop doing this?","Why didn't he come and talk to me himself?","Promise me you'll look after your mother.","If you get me his phone, I might reconsider.","I think the room is bugged.","No! I'm tired of doing what you say.","For some reason, I'm attracted to you."]
        return convoList.randomItem()
    }
    
    public static func randomFakeTitle() -> String {
        let titleList = ["CEO of Google", "CEO of Facebook", "VP of Marketing @Uber", "Business Developer at IBM", "Jungler @ Fanatic", "B2 Pilot @ USAF", "Student at Stanford", "Student at Harvard", "Mayor of Raccoon City", "CTO @ Umbrella Corporation", "Professor at Pallet Town University"]
        return titleList.randomItem()
    }
    
    public static func randomFakeTag() -> String {
        let tagList = ["meta", "forum", "troll", "meme", "question", "important", "like4like", "f4f"]
        return tagList.randomItem()
    }
    
    private static func randomEnglishHonorific() -> String {
        let englishHonorificsList = ["Mr.", "Ms.", "Dr.", "Mrs.", "Mz.", "Mx.", "Prof."]
        return englishHonorificsList.randomItem()
    }
    
    public static func randomFakeNameAndEnglishHonorific() -> String {
        let englishHonorific = randomEnglishHonorific()
        let name = randomFakeName()
        return englishHonorific + " " + name
    }
    
    public static func randomFakeCity() -> String {
        let cityPrefixes = ["North", "East", "West", "South", "New", "Lake", "Port"]
        let citySuffixes = ["town", "ton", "land", "ville", "berg", "burgh", "borough", "bury", "view", "port", "mouth", "stad", "furt", "chester", "mouth", "fort", "haven", "side", "shire"]
        return cityPrefixes.randomItem() + citySuffixes.randomItem()
    }
    
    public static func randomCurrency() -> String {
        let currencyList = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "ZAR", "NZD", "INR", "BRP", "CNY", "EGP", "KRW", "MXN", "SAR", "SGD",]
        
        return currencyList.randomItem()
    }
    
    public enum GravatarStyle: String {
        case Standard
        case MM
        case Identicon
        case MonsterID
        case Wavatar
        case Retro
        
        static let allValues = [Standard, MM, Identicon, MonsterID, Wavatar, Retro]
    }
  
}
