/*
 * Copyright (c) 2020, Psiphon Inc.
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

#import <Foundation/Foundation.h>
#import "Psiphon-Swift.h"

@class RACReplaySubject<ValueType>;
@class RACMulticastConnection<__covariant ValueType>;
@class BridgedUserSubscription;

NS_ASSUME_NONNULL_BEGIN

@interface AppObservables: NSObject

/**
 * subscriptionStatus emits an item of type `UserSubscriptionStatus` wrapped in NSNumber.
 * This replay subject has the initial value of `UserSubscriptionUnknown`.
 *
 * @note This subject might emit non-unique events.
 *
 */
@property (nonatomic, readonly) RACReplaySubject<BridgedUserSubscription *> *subscriptionStatus;

@property (nonatomic, readonly) RACReplaySubject<ObjcSubscriptionBarViewState *> *subscriptionBarStatus;

@property (nonatomic, readonly) RACReplaySubject<BridgedBalanceViewBindingType *> *psiCashBalance;

// Contained value is nil if there is not Speed Boost purchase.
@property (nonatomic, readonly) RACReplaySubject<NSDate *> *speedBoostExpiry;

// Wraps VPN status of type `NEVPNStatus`.
@property (nonatomic, readonly) RACReplaySubject<NSNumber *> *vpnStatus;

// Wraps VPN start stop state status of type `VPNStartStopStatus`.
@property (nonatomic, readonly) RACReplaySubject<NSNumber *> *vpnStartStopStatus;

// reachabilityStatus subject forwards AppState `internetReachability` ReachabilityStatus values.
@property (nonatomic, readonly) RACReplaySubject<NSNumber *> *reachabilityStatus;

// isLoggedInToPsiCashAccount carries BOOL wrapped in NSNumber.
// Values are forwarded from AppState.

@property (nonatomic, readonly) RACReplaySubject<NSNumber *> *isLoggedInToPsiCashAccount;

+ (AppObservables *)shared;

// Should be called when app is launched for the first time.
- (void)appLaunched;

@end

NS_ASSUME_NONNULL_END
