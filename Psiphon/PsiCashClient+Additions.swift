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
import PsiApi
import PsiCashClient

extension PsiCashRequestError: LocalizedUserDescription where ErrorStatus: LocalizedUserDescription {
    
    public var localizedUserDescription: String {
        switch self {
        case .errorStatus(let errorStatus):
            return errorStatus.localizedUserDescription
        case .requestFailed(let psiCashLibError):
            return psiCashLibError.localizedDescription
        }
    }
    
}

extension TunneledPsiCashRequestError: LocalizedUserDescription where
    RequestError: LocalizedUserDescription {

    public var localizedUserDescription: String {
        switch self {
        case .tunnelNotConnected:
            return UserStrings.Psiphon_is_not_connected()
        case .requestError(let requestError):
            return requestError.localizedUserDescription
        }
    }

}

extension PsiCashNewExpiringPurchaseErrorStatus: LocalizedUserDescription {
    
    public var localizedUserDescription: String {
        switch self {
        case .insufficientBalance:
            return UserStrings.Insufficient_psiCash_balance()
        default:
            return UserStrings.Operation_failed_please_try_again_alert_message()
        }
    }
    
}

extension PsiCashNewExpiringPurchaseErrorStatus {
    
    /// Whether or not the request should be retried given this status.
    var shouldRetry: Bool {
        switch self {
        case .serverError:
            return true
        case .existingTransaction,
             .insufficientBalance,
             .transactionAmountMismatch,
             .transactionTypeNotFound,
             .invalidTokens:
            return false
        }
    }
    
}

extension PsiCashAmount: CustomStringFeedbackDescription {
    
    public var description: String {
        "PsiCash(inPsi: \(String(format: "%.2f", self.inPsi)))"
    }
    
}


fileprivate struct PsiCashHTTPResponse: HTTPResponse {
    typealias Success = PSIHttpResult
    typealias Failure = Never
    
    var result: ResultType
    
    var psiHTTPResult: PSIHttpResult {
        result.successToOptional()!
    }
    
    init(urlSessionResult: URLSessionResult) {
        switch urlSessionResult.result {
        case let .success(r):
            
            let statusCode = Int32(r.metadata.statusCode.rawValue)
            
            guard let body = String(data: r.data, encoding: .utf8) else {
                result = .success(PSIHttpResult(criticalError: ()))
                return
            }
            
            let psiHttpResult = PSIHttpResult(
                code: statusCode,
                headers: r.metadata.headers.mapValues { [$0] },
                body: body,
                error: "")
            
            result = .success(psiHttpResult)
            
        case let .failure(httpRequestError):
            if let partialResponse = httpRequestError.partialResponseMetadata {
                let statusCode = Int32(partialResponse.statusCode.rawValue)
                
                let psiHttpResult = PSIHttpResult(
                    code: statusCode,
                    headers: partialResponse.headers.mapValues { [$0] },
                    body: "",
                    error: "")
                
                result = .success(psiHttpResult)
                
            } else {
                let psiHttpResult = PSIHttpResult(
                    code: PSIHttpResult.recoverable_ERROR(),
                    headers: [String: [String]](),
                    body: "",
                    error: "")
                
                result = .success(psiHttpResult)
            }
        }
    }
    
}


extension PsiCashEffects {
    
    static func `default`(
        psiCash: PsiCash,
        httpClient: HTTPClient,
        globalDispatcher: GlobalDispatcher,
        getCurrentTime: @escaping () -> Date,
        feedbackLogger: FeedbackLogger
    ) -> PsiCashEffects {
        PsiCashEffects(
            initialize: { [psiCash] (fileStoreRoot: String?, psiCashLegacyDataStore: UserDefaults)
                -> Effect<Result<PsiCashLibInitSuccess, ErrorRepr>> in
                Effect { () -> Result<PsiCashLibInitSuccess, ErrorRepr> in

                    guard let fileStoreRoot = fileStoreRoot else {
                        return .failure(ErrorRepr(repr: "nil psicash file store root"))
                    }
                    
                    let initResult = psiCash.initialize(
                        userAgent: PsiCashClientHardCodedValues.userAgent,
                        fileStoreRoot: fileStoreRoot,
                        psiCashLegacyDataStore: psiCashLegacyDataStore,
                        httpRequestFunc: { (request: PSIHttpRequest) -> PSIHttpResult in
                            
                            // Maps [PSIPair<NSString>] to Swift type `[(String, String)]`.
                            let queryParams: [(String, String)] = request.query.map {
                                ($0.first as String, $0.second as String)
                            }
                            
                            guard let httpMethod = HTTPMethod(rawValue: request.method) else {
                                return PSIHttpResult(criticalError: ())
                            }
                            
                            let maybeUrl = URL.make(scheme: request.scheme, hostname: request.hostname,
                                                    port: request.port, path: request.path,
                                                    queryParams: queryParams)
                            
                            guard let url = maybeUrl else {
                                return PSIHttpResult(criticalError: ())
                            }
                            
                            let httpRequest = HTTPRequest(url: url,
                                                          httpMethod: httpMethod,
                                                          headers: request.headers,
                                                          body: request.body.data(using: .utf8),
                                                          response: PsiCashHTTPResponse.self)
                            
                            
                            // Makes async HTTPClient call into a sync call.
                            let sem = DispatchSemaphore(value: 0)
                            
                            var response: PsiCashHTTPResponse? = nil
                            
                            // Ignores `CancellableURLRequest` return value, as PsiCash
                            // requests are never cancelled.
                            let _ = httpClient.request(getCurrentTime, httpRequest) {
                                response = $0
                                sem.signal()
                            }
                            sem.wait()
                            
                            return response!.psiHTTPResult
                        },
                        test: Debugging.devServers)
                    
                    switch initResult {
                    case .success(let requiredStateRefresh):
                        return .success(
                            PsiCashLibInitSuccess(
                                libData: psiCash.dataModel,
                                requiresStateRefresh: requiredStateRefresh
                            )
                        )
                    case .failure(let error):
                        return .failure(ErrorRepr(repr: String(describing: error)))
                    }
                }
            } ,
            libData: { [psiCash] () -> PsiCashLibData in
                psiCash.dataModel
            },
            refreshState: { [psiCash, getCurrentTime] (priceClasses, tunnelConnection, metadata) ->
                Effect<PsiCashEffects.PsiCashRefreshResult> in
                Effect.deferred(dispatcher: globalDispatcher) { fulfilled in
                    guard case .connected = tunnelConnection.tunneled else {
                        fulfilled(
                            .failure(
                                ErrorEvent(.tunnelNotConnected, date: getCurrentTime())
                            )
                        )
                        return
                    }
                    
                    // Updates request metadata before sending the request.
                    let maybeError = psiCash.setRequestMetadata(metadata)
                    guard maybeError == nil else {
                        feedbackLogger.fatalError("failed to set request metadata")
                        return
                    }
                    
                    let purchaseClasses = priceClasses.map(\.rawValue)
                    
                    // Blocking call.
                    let result = psiCash.refreshState(purchaseClasses: purchaseClasses)
                    
                    fulfilled(
                        result.mapError {
                            ErrorEvent(.requestError($0), date: getCurrentTime())
                        }
                    )
                }
            },
            purchaseProduct: { [psiCash, feedbackLogger, getCurrentTime]
                (purchasable, tunnelConnection, metadata) ->
                Effect<PsiCashEffects.NewExpiringPurchaseResult> in
                
                Effect.deferred(dispatcher: globalDispatcher) { fulfilled in
                    guard case .connected = tunnelConnection.tunneled else {
                        fulfilled(
                            PsiCashEffects.NewExpiringPurchaseResult(
                                refreshedLibData: psiCash.dataModel,
                                result: .failure(ErrorEvent(.tunnelNotConnected,
                                                            date: getCurrentTime())))
                        )
                        return
                    }
                    
                    feedbackLogger.immediate(.info,
                                             "Purchase: '\(String(describing: purchasable))'")
                    
                    // Updates request metadata before sending the request.
                    let maybeError = psiCash.setRequestMetadata(metadata)
                    guard maybeError == nil else {
                        feedbackLogger.fatalError("failed to set request metadata")
                        return
                    }
                    
                    // Blocking call.
                    let result = psiCash.newExpiringPurchase(purchasable: purchasable)
                    
                    fulfilled(
                        PsiCashEffects.NewExpiringPurchaseResult(
                            refreshedLibData: psiCash.dataModel,
                            result: result.mapError {
                                return ErrorEvent(.requestError($0),
                                                  date: getCurrentTime())
                            }
                        )
                    )
                }
            },
            modifyLandingPage: { [psiCash, feedbackLogger] url -> Effect<URL> in
                Effect { () -> URL in
                    switch psiCash.modifyLandingPage(url: url.absoluteString) {
                    case .success(let modifiedURL):
                        return URL(string: modifiedURL)!
                    case .failure(let error):
                        feedbackLogger.immediate(.error, "failed to modify url: '\(error))'")
                        return url
                    }
                }
                
            },
            rewardedVideoCustomData: { [psiCash, feedbackLogger] () -> String? in
                switch psiCash.getRewardActivityData() {
                case .success(let rewardActivityData):
                    return rewardActivityData
                case .failure(let error):
                    feedbackLogger.immediate(.error, "GetRewardedActivityDataFailed: '\(error)'")
                    return nil
                }
            },
            removePurchasesNotIn: { [psiCash]
                (nonSubscriptionEncodedAuthorization: Set<String>) -> Effect<Never> in
                .fireAndForget {
                    let decoder = JSONDecoder.makeRfc3339Decoder()
                    
                    let nonSubscriptionAuthIDs = nonSubscriptionEncodedAuthorization
                        .compactMap { encodedAuth -> SignedAuthorization? in
                            guard let data = encodedAuth.data(using: .utf8) else {
                                return nil;
                            }
                            return try? decoder.decode(SignedAuthorization.self, from: data)
                        }.map(\.authorization.id)
                    
                    let result = psiCash.removePurchases(notFoundIn: nonSubscriptionAuthIDs)
                    switch result {
                    case .success(_):
                        return
                    case .failure(let error):
                        feedbackLogger.immediate(.error, "removePurchasesNotIn failed: \(error)")
                    }
                }
            },
            accountLogout: { [psiCash, getCurrentTime] tunnelConnection
                -> Effect<PsiCashAccountLogoutResult> in
                Effect.deferred(dispatcher: globalDispatcher) { fulfilled in
                    // This may involve a network operation and so can be blocking.
                    
                    guard case .connected = tunnelConnection.tunneled else {
                        fulfilled(
                            .failure(ErrorEvent(.tunnelNotConnected, date: getCurrentTime()))
                        )
                        return
                    }
                    
                    fulfilled(
                        psiCash.accountLogout()
                            .optionalToFailure(success: psiCash.dataModel)
                            .mapError { ErrorEvent(.requestError($0), date: getCurrentTime()) }
                    )
                }
            },
            accountLogin: { [psiCash, getCurrentTime] tunnelConnection, username, password
                -> Effect<PsiCashAccountLoginResult> in
                Effect.deferred(dispatcher: globalDispatcher) { fulfilled in
                    
                    guard case .connected = tunnelConnection.tunneled else {
                        fulfilled(
                            .failure(ErrorEvent(.tunnelNotConnected, date: getCurrentTime()))
                        )
                        return
                    }
                    
                    // This is a blocking call.
                    let result = psiCash.accountLogin(username: username, password: password)
                    
                    fulfilled(
                        result.mapError {
                            ErrorEvent(.requestError($0), date: getCurrentTime())
                        }
                    )
                }
            }
        )
    }
    
}
