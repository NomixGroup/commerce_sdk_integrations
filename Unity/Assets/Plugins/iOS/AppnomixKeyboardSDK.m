//
//  AppnomixKeyboardSDK.m
//  Unity-iPhone
//
//  Created by Andrei Sava on 03.03.2025.
//

#import "AppnomixKeyboardSDK.h"
#include "UnityFramework/UnityFramework-Swift.h"

void AppnomixKeyboardSDK_showOnboarding() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [AppnomixSwiftWrapper showOnboardingScreen]; // Call Swift function
    });
}
