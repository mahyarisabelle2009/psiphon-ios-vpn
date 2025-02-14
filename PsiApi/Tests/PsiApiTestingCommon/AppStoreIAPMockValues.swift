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

import Foundation
import ReactiveSwift
import PsiCashClient
import Testing
import StoreKit
import SwiftCheck
import Utilities
@testable import PsiApi
@testable import AppStoreIAP

extension ReceiptData {
    
    static func mock(
        subscriptionInAppPurchases: Set<SubscriptionIAPPurchase> = Set([]),
        consumableInAppPurchases: Set<ConsumableIAPPurchase> = Set([]),
        readDate: Date = Date()
    ) -> ReceiptData {
        ReceiptData(
            filename: "receipt", // unused in tests.
            subscriptionInAppPurchases: subscriptionInAppPurchases,
            consumableInAppPurchases: consumableInAppPurchases,
            data: Data(), // unused in tests.
            readDate: readDate
        )
    }
    
}

extension PsiCashEffects {
    
    static func mock(
        initGen: Gen<Result<PsiCashLibData, ErrorRepr>>? = nil,
        libData: Gen<PsiCashLibData>? = nil,
        refreshState: Gen<PsiCashRefreshResult>? = nil,
        purchaseProduct: Gen<PsiCashPurchaseResult>? = nil,
        modifyLandingPage: Gen<URL>? = nil,
        rewardedVideoCustomData: Gen<String>? = nil
    ) -> PsiCashEffects {
        
        .init { fileStoreRoot -> Effect<Result<PsiCashLibData, ErrorRepr>> in
            Effect(value: returnGeneratedOrFail(initGen))
        } libData: { () -> PsiCashLibData in
            returnGeneratedOrFail(libData)

        } refreshState: { (_, _, _) -> Effect<PsiCashRefreshResult> in
            Effect(value: returnGeneratedOrFail(refreshState))
            
        } purchaseProduct: { (_, _, _) -> Effect<PsiCashPurchaseResult> in
            Effect(value: returnGeneratedOrFail(purchaseProduct))
            
        } modifyLandingPage: { (_) -> Effect<URL> in
            Effect(value: returnGeneratedOrFail(modifyLandingPage))
            
        } rewardedVideoCustomData: { () -> String? in
            returnGeneratedOrFail(rewardedVideoCustomData)
            
        } removePurchasesNotIn: { (_) -> Effect<Never> in
            return .empty
        }
        
    }
    
}

extension PaymentQueue {
    
    static func mock(
        transactions: Gen<[PaymentTransaction]>? = nil,
        addPayment: ((AppStoreProduct) -> Effect<Never>)? = nil,
        finishTransaction: ((PaymentTransaction) -> Effect<Never>)? = nil
    ) -> PaymentQueue {
        return PaymentQueue(
            transactions: { () -> Effect<[PaymentTransaction]> in
                Effect(value: returnGeneratedOrFail(transactions))
            },
            addPayment: { product -> Effect<Never> in
                guard let addPayment = addPayment else { XCTFatal() }
                return addPayment(product)
            },
            addObserver: { _ -> Effect<Never> in
                return .empty
            },
            removeObserver: { _ -> Effect<Never> in
                return .empty
            },
            finishTransaction: { paymentTx -> Effect<Never> in
                guard let f = finishTransaction else {
                    XCTFatal()
                }
                return f(paymentTx)
            })
    }
    
}

extension IAPEnvironment {
    
    static func mock(
        _ feedbackLogger: FeedbackLogger,
        tunnelStatusSignal: @autoclosure () -> SignalProducer<TunnelProviderVPNStatus, Never>? = nil,
        tunnelConnectionRefSignal: @autoclosure () -> SignalProducer<TunnelConnection?, Never>? = nil,
        psiCashEffects: PsiCashEffects? = nil,
        paymentQueue: PaymentQueue? = nil,
        clientMetaData: (() -> ClientMetaData)? = nil,
        isSupportedProduct: ((ProductID) -> AppStoreProductType?)? = nil,
        psiCashStore: ((PsiCashAction) -> Effect<Never>)? = nil,
        appReceiptStore: ((ReceiptStateAction) -> Effect<Never>)? = nil,
        httpClient: HTTPClient? = nil,
        getCurrentTime: (() -> Date)? = nil
    ) -> IAPEnvironment {

        let _tunnelStatusSignal = tunnelStatusSignal() ?? SignalProducer(value: .connected)
        
        let _tunnelConnectionRefSignal = tunnelConnectionRefSignal() ??
            SignalProducer(value: .some(TunnelConnection { .connection(.connected) }))
            
        return IAPEnvironment(
            feedbackLogger: feedbackLogger,
            tunnelStatusSignal: _tunnelStatusSignal,
            tunnelConnectionRefSignal: _tunnelConnectionRefSignal,
            psiCashEffects: psiCashEffects ?? PsiCashEffects.mock(),
            clientMetaData: clientMetaData ?? { ClientMetaData(MockAppInfoProvider()) },
            paymentQueue: paymentQueue ?? PaymentQueue.mock(),
            psiCashPersistedValues: MockPsiCashPersistedValues(),
            isSupportedProduct: isSupportedProduct ?? { _ in XCTFatal() },
            psiCashStore: psiCashStore ?? { _ in XCTFatal() },
            appReceiptStore: appReceiptStore ?? { _ in XCTFatal() },
            httpClient: httpClient ?? EchoHTTPClient().client,
            getCurrentTime: getCurrentTime ?? { XCTFatal() }
        )
    }
    
}
