//
//  AppnomixSwiftWrapper.swift
//  Unity-iPhone
//
//  Created by Andrei Sava on 03.03.2025.
//

import UIKit

@objc public class AppnomixSwiftWrapper: NSObject {
    @objc public static func showOnboardingScreen() {
        NotificationCenter.default.post(
            name: NSNotification.Name("AppnomixShowOnboarding"),
            object: nil)
    }
}
