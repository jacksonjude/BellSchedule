//
//  UserScheduleTableViewController.swift
//  Schedule
//
//  Created by jackson on 10/10/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CloudKit

class UserScheduleTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    let numberOfPeriods = 9
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfPeriods
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}
