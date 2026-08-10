//
//  AppDelegate.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
