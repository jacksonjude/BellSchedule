//
//  CalendarCollectionView.swift
//  Schedule
//
//  Created by jackson on 10/11/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

class CalendarCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout
{
    fileprivate let reuseIdentifier = "CalendarDayCell"
    fileprivate let loadedWeeks = 5
    fileprivate let itemsPerRow: CGFloat = 7
    fileprivate let sectionInsets = UIEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
    @IBOutlet weak var collectionView: UICollectionView!
    let appDelegate = UIApplication.shared.delegate! as! AppDelegate
    var currentDateString: String?
    var weekScheduleCodes: Array<String> = []
    var weekOn = 0
    
    override func viewDidLoad() {
        print("Loaded Calender!")
        fetchAllWeeks(weeksToAdd: 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addCorners(view: collectionView)
    }
    
    func addCorners(view: UIView)
    {
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section
        {
        case 0:
            return 7
        case 1:
            return loadedWeeks*7
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        
        addCorners(view: cell)
        
        switch indexPath.section
        {
        case 0:
            let stringDayOfWeek = String(Date().getStringDayOfWeek(day: indexPath.row))
            (cell.viewWithTag(618) as! UILabel).text = String(stringDayOfWeek[stringDayOfWeek.startIndex])
            (cell.viewWithTag(618) as! UILabel).textColor = UIColor.white
            cell.backgroundColor = UIColor(red: CGFloat(0.427), green: CGFloat(0.427), blue: CGFloat(0.427), alpha: 1)
        case 1:
            (cell.viewWithTag(618) as! UILabel).text = String(describing: getDate(indexPath: indexPath).day!)
            cell.backgroundColor = UIColor.white
        default:
            break
        }
        
        return cell
    }
    
    func getDate(indexPath: IndexPath) -> DateComponents
    {
        var cellDate = Date().startOfWeek!
        cellDate.addTimeInterval(TimeInterval(60*60*24*indexPath.row+3600))
        let cellDateComponents = Date.Gregorian.calendar.dateComponents([.day, .month, .year, .hour, .minute, .second], from: cellDate)
        return cellDateComponents
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 1
        {
            let dateComponents = getDate(indexPath: indexPath)
            
            currentDateString = zeroPadding(int: dateComponents.month!) + "/" + zeroPadding(int: dateComponents.day!) + "/" + zeroPadding(int: dateComponents.year!)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            let dateFromComponents = dateFormatter.date(from: currentDateString!)
            
            let startOfWeekDate = Date.Gregorian.calendar.date(from: Date.Gregorian.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: dateFromComponents!))
            
            fetchWeek(date: startOfWeekDate!, selector: #selector(receiveWeek(notification:)))
        }
    }
    
    func fetchWeek(date: Date, selector: Selector)
    {
        print(" FWSCH: Fetching weekScheduleRecord")
        let weekScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: selector, name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + weekScheduleReturnID), object: nil)
        
        let gregorian = Calendar(identifier: .gregorian)
        var components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.hour = 12
        let startOfWeekFormatted = gregorian.date(from: components)!
        
        let weekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfWeekFormatted as CVarArg)
        appDelegate.cloudManager.fetchPublicDatabaseObject(type: "WeekSchedules", predicate: weekScheduleQueryPredicate, returnID: weekScheduleReturnID)
    }
    
    @objc func receiveWeek(notification: NSNotification)
    {
        if let weekScheduleRecord = notification.object as? CKRecord
        {
            print(" FWSCH: Received weekScheduleRecord")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            let currentDate = dateFormatter.date(from: currentDateString!)
            
            let gregorian = Calendar(identifier: .gregorian)
            let weekdayComponents = gregorian.dateComponents([.weekday], from: currentDate!)
            
            let schedules = weekScheduleRecord.object(forKey: "schedules") as! Array<String>
            let dayOfWeek = weekdayComponents.weekday!-2
            if 0 <= dayOfWeek && dayOfWeek < schedules.count
            {
                fetchSchedule(scheduleCode: schedules[dayOfWeek])
            }
            else
            {
                alertUser(message: "Code: N/A\nNo school!")
            }
        }
        else
        {
            print(" FWSCH: Did not receive weekScheduleRecord")
        }
    }
    
    func zeroPadding(int: Int) -> String
    {
        if int > 9
        {
            return String(int)
        }
        else
        {
            return "0" + String(int)
        }
    }
    
    func fetchSchedule(scheduleCode: String)
    {
        print(" FDSCH: Fetching schedule")
        
        let scheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + scheduleReturnID), object: nil)
        
        let scheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", scheduleCode)
        appDelegate.cloudManager.fetchPublicDatabaseObject(type: "Schedule", predicate: scheduleQueryPredicate, returnID: scheduleReturnID)
    }
    
    @objc func receiveSchedule(notification: NSNotification)
    {
        if let scheduleRecord = notification.object as? CKRecord
        {
            print(" FDSCH: Received scheduleRecord")
            
            findTimes(scheduleRecord: scheduleRecord)
        }
        else
        {
            print(" FDSCH: Did not receive scheduleRecord")
        }
    }
    
    func findTimes(scheduleRecord: CKRecord)
    {
        let scheduleCode = scheduleRecord.object(forKey: "scheduleCode") as! String
        
        var startTime: String? = nil
        var endTime: String? = nil
        var schoolToday = true
        if scheduleCode != "H"
        {
            let schedules = scheduleRecord.object(forKey: "periodTimes") as! Array<String>
            startTime = String(schedules[0].split(separator: "-")[0])
            endTime = String(schedules[schedules.count-1].split(separator: "-")[1])
        }
        else
        {
            schoolToday = false
        }
        
        var message = ""
        if schoolToday
        {
            let message1 = "Code: " + scheduleCode + "\nStart: "
            let message2 =  Date().convertToStandardTime(date: startTime!) + "\nEnd: " + Date().convertToStandardTime(date: endTime!)
            message = message1 + message2
        }
        else
        {
            message = "Code: H\nNo school!"
        }
        
        alertUser(message: message)
    }
    
    func alertUser(message: String)
    {
        let schoolTimeAlert = UIAlertController(title: currentDateString!, message: message, preferredStyle: .alert)
        
        schoolTimeAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (alert) in
            
        }))
        
        self.present(schoolTimeAlert, animated: true) {
            
        }
    }
    
    func fetchAllWeeks(weeksToAdd: Int)
    {
        if weeksToAdd < loadedWeeks
        {
            var startOfWeekToFetch = Date().startOfWeek!
            startOfWeekToFetch.addTimeInterval(TimeInterval(60*60*24*7*weeksToAdd))
            fetchWeek(date: startOfWeekToFetch, selector: #selector(receiveWeekInFetchAllWeeks(notification:)))
            weekOn+=1
        }
        else
        {
            print(weekScheduleCodes)
        }
    }
    
    @objc func receiveWeekInFetchAllWeeks(notification: NSNotification)
    {
        if let weekScheduleRecord = notification.object as? CKRecord
        {
            print(" FWSCH: Received weekScheduleRecord")
            
            let schedules = weekScheduleRecord.object(forKey: "schedules") as! Array<String>
            for schedule in schedules
            {
                weekScheduleCodes.append(schedule)
            }
            
            fetchAllWeeks(weeksToAdd: weekOn)
        }
        else
        {
            print(" FWSCH: Did not receive weekScheduleRecord")
        }
    }
}
