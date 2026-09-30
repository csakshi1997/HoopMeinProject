//
//  TabbarView.swift
//  FRATELLI
//
//  Created by Sakshi on 21/10/24.
//

import UIKit

class TabbarView: UIViewController {
    @IBOutlet var selectedSmallTabOne: UIImageView?
    @IBOutlet var selectedSmallTabTwo: UIImageView?
    @IBOutlet var selectedSmallTabThree: UIImageView?
    @IBOutlet var selectedSmallTabFour: UIImageView?
    @IBOutlet var fourBtnViewView: UIView?
    @IBOutlet var bottomView: UIView?
    var homeView: UIViewController?
    var timeline: UIViewController?
    var customers: UIViewController?
    var profile: UIViewController?
    var customTabBar = CustomTabBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectedSmallTabOne?.image = UIImage(named: "home_selected")
        selectedSmallTabTwo?.image = UIImage(named: "timeline_unselected")
        selectedSmallTabThree?.image = UIImage(named: "logout_unselected")
        selectedSmallTabFour?.image = UIImage(named: "profile_unselected")
        goToHomeView()
        fourBtnViewView?.layer.cornerRadius = 30
        bottomView?.layer.cornerRadius = 30
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
    
    func gotoTimeLineView() {
        removeAllChildViews()
        selectedSmallTabTwo?.image = UIImage(named: "timeline_selected")
        let storyBoard : UIStoryboard = UIStoryboard(name: "Timeline", bundle:nil)
        timeline = storyBoard.instantiateViewController(withIdentifier: "TimelineVC") as? TimelineVC ?? TimelineVC()
        self.add(timeline ?? TimelineVC(), frame: self.view.bounds)
        self.view.bringSubviewToFront(bottomView ?? UIView())
    }
    
    func gotoPunchOutView() {
        let punchOutAlert = UIAlertController(
            title: "Logout from HoopMeIn",
            message: "Are you sure you want to logout? This will clear all your cached data and stop location tracking.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
            
            Utility.logoutAction()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        punchOutAlert.addAction(okAction)
        punchOutAlert.addAction(cancelAction)
        
        present(punchOutAlert, animated: true)
    }
    
    func gotoProfileView() {
        removeAllChildViews()
        selectedSmallTabFour?.image = UIImage(named: "profile_selected")
        let storyBoard : UIStoryboard = UIStoryboard(name: "Profile", bundle:nil)
        profile = storyBoard.instantiateViewController(withIdentifier: "ProfileVC") as? ProfileVC ?? ProfileVC()
        self.add(profile ?? ProfileVC(), frame: self.view.bounds)
        self.view.bringSubviewToFront(bottomView ?? UIView())
    }
    
    func goToHomeView() {
        removeAllChildViews()
        selectedSmallTabOne?.image = UIImage(named: "home_selected")
        let storyBoard : UIStoryboard = UIStoryboard(name: "Home", bundle:nil)
        homeView = storyBoard.instantiateViewController(withIdentifier: "HomeVC") as? HomeVC ?? HomeVC()
        self.add(homeView ?? HomeVC(), frame: self.view.bounds)
        self.view.bringSubviewToFront(bottomView ?? UIView())
    }
        
    func removeAllChildViews() {
        homeView?.remove()
        timeline?.remove()
        profile?.remove()
    }
    
    @IBAction func tabSelection(button: UIButton?) {
        selectedSmallTabOne?.image = UIImage(named: "home_unselected")
        selectedSmallTabTwo?.image = UIImage(named: "timeline_unselected")
        selectedSmallTabThree?.image = UIImage(named: "logout_unselected")
        selectedSmallTabFour?.image = UIImage(named: "profile_unselected")
        if button?.tag ?? 0 == 1 {
            goToHomeView()
        } else if button?.tag ?? 0 == 2 {
            gotoTimeLineView()
        } else if button?.tag ?? 0 == 3 {
            gotoPunchOutView()
        } else if button?.tag ?? 0 == 4 {
            gotoProfileView()
        }
    }
}


