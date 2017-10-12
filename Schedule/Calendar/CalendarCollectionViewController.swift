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
    fileprivate let sectionInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addCorners(view: collectionView)
    }
    
    func addCorners(view: UIView)
    {
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return loadedWeeks*7
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        cell.backgroundColor = UIColor(red: CGFloat(0.937), green: CGFloat(0.937), blue: CGFloat(0.937), alpha: 1)
        
        var cellDate = Date().startOfWeek!
        cellDate.addTimeInterval(TimeInterval(60*60*24*indexPath.row))
        let cellDateComponents = Date.Gregorian.calendar.dateComponents([.day, .month, .year], from: cellDate)
        let cellDayOfMonth = cellDateComponents.day!
        
        (cell.viewWithTag(618) as! UILabel).text = String(describing: cellDayOfMonth)
        addCorners(view: cell)
        return cell
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
        //Load schedule for day, and alert user
    }
}
