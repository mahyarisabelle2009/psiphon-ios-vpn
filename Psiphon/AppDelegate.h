/*
 * Copyright (c) 2015, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (AppDelegate *)sharedAppDelegate;

- (void)reloadMainViewControllerAndImmediatelyOpenSettings;

- (void)reloadOnboardingViewController;

- (void)startStopVPNWithAd:(BOOL)showAd;

/**
 Returns top most view controller in the presented stack from the app's key window.
 
 This returns the top most view controller that is modally presented, so the returned view controller
 might have child view controllers, but it's `presentedViewController` property is `nil`.
 */
+ (UIViewController *)getTopPresentedViewController;

@end

NS_ASSUME_NONNULL_END
