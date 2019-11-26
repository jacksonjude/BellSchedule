//
//  ScheduleDataManager.swift
//  ScheduleWatch Extension
//
//  Created by jackson on 11/26/19.
//  Copyright © 2019 jackson. All rights reserved.
//

import Foundation

class ScheduleDataManager
{
    static let todaySource = URL(string: "https://lowellschedule.herokuapp.com/today")!
    static let tomorrowSource = URL(string: "https://lowellschedule.herokuapp.com/tomorrow")!
    
    static var todayScheduleData: Dictionary<String,Any>?
    static var tomorrowScheduleData: Dictionary<String,Any>?
    
    static func fetchScheduleData(source: URL, completion: @escaping (Dictionary<String,Any>) -> Void)
    {
        let scheduleTask = URLSession.shared.dataTask(with: source) { (data, response, error) in
            guard let data = data else { return }
            if let scheduleDictionary = self.decodeJSONFromData(data: data)
            {
                completion(scheduleDictionary)
            }
        }
        
        scheduleTask.resume()
    }
    
    static func fetchTodayData(completion: @escaping (Dictionary<String,Any>) -> Void)
    {
        self.fetchScheduleData(source: todaySource, completion: { (todayData) in
            self.todayScheduleData = todayData
            completion(todayData)
        })
    }
    
    static func fetchTomorrowData(completion: @escaping (Dictionary<String,Any>) -> Void)
    {
        self.fetchScheduleData(source: tomorrowSource) { (tomorrowData) in
            self.tomorrowScheduleData = tomorrowData
            completion(tomorrowData)
        }
    }
    
    static func decodeJSONFromData(data: Data) -> Dictionary<String,Any>?
    {
        do
        {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String,Any>
            {
                return jsonObject
            }
        }
        catch
        {
            print(error)
        }
        return nil
    }
    
    static func convertRangeTo12Hour(_ range: String) -> String
    {
        let rangeStart = convertTimeTo12Hour(String(range.split(separator: "-")[0]))
        let rangeEnd = convertTimeTo12Hour(String(range.split(separator: "-")[1]))

        return rangeStart + "-" + rangeEnd
    }

    static func convertTimeTo12Hour(_ time: String) -> String
    {
        let hour = convertTo12Hour(Int(String(time.split(separator: ":")[0]))!)
        let minute = time.split(separator: ":")[1]

        return zeroPadding(hour) + ":" + String(minute)
    }

    static func convertTo12Hour(_ hour: Int) -> Int
    {
        if hour > 12 { return hour-12 }
        if hour == 0 { return 12 }
        return hour
    }
    
    static func zeroPadding(_ n: Int) -> String
    {
      if (n < 10) { return "0" + String(n) }
      return String(n)
    }
}
