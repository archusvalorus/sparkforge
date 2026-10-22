// Explicit UIKit/ATT/UMP/GMA fakes for executing the actual platform/manager bodies.
import Foundation
@MainActor enum PlatformCalls {
    static var att = 0; static var ump = 0; static var ads = 0
}
@MainActor class UIViewController {
    final class View { var window: NSObject? = NSObject() }
    var viewIfLoaded: View? = View()
    var presentedViewController: UIViewController?
    var isBeingDismissed = false
    func viewDidAppear(_ animated: Bool) {}
}
class UIScene {}
@MainActor final class UIApplication {
    enum State { case active, inactive }
    static let shared = UIApplication()
    var applicationState: State = .active
}
@MainActor enum ATTrackingManager {
    enum Status { case authorized, denied, restricted, notDetermined }
    static var trackingAuthorizationStatus: Status { PlatformCalls.att += 1; return .notDetermined }
    static func requestTrackingAuthorization(_ completion: @escaping (Status) -> Void) { PlatformCalls.att += 1; completion(.denied) }
}
@MainActor final class RequestParameters { init() { PlatformCalls.ump += 1 } }
@MainActor final class ConsentInformation {
    enum Requirement { case required, notRequired }
    private static let instance = ConsentInformation()
    static var shared: ConsentInformation { PlatformCalls.ump += 1; return instance }
    var canRequestAds: Bool { PlatformCalls.ump += 1; return true }
    var privacyOptionsRequirementStatus: Requirement { PlatformCalls.ump += 1; return .required }
    func requestConsentInfoUpdate(with: RequestParameters, completion: @escaping (Error?) -> Void) { PlatformCalls.ump += 1; completion(nil) }
}
@MainActor enum ConsentForm {
    static func loadAndPresentIfRequired(from: UIViewController, completion: @escaping (Error?) -> Void) { PlatformCalls.ump += 1; completion(nil) }
    static func presentPrivacyOptionsForm(from: UIViewController, completion: @escaping (Error?) -> Void) { PlatformCalls.ump += 1; completion(nil) }
}
@MainActor final class MobileAds {
    private static let instance = MobileAds()
    static var shared: MobileAds { PlatformCalls.ads += 1; return instance }
    func start(_ completion: @escaping (Int) -> Void) { PlatformCalls.ads += 1; completion(0) }
}
final class Request {}
protocol FullScreenPresentingAd {}
protocol FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error)
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd)
}
@MainActor final class RewardedAd: FullScreenPresentingAd {
    var fullScreenContentDelegate: FullScreenContentDelegate?
    static var loads = 0; static var presentations = 0
    static func load(with: String, request: Request, completion: @escaping (RewardedAd?, Error?) -> Void) { loads += 1; completion(RewardedAd(), nil) }
    func present(from: UIViewController, userDidEarnRewardHandler: @escaping () -> Void) { Self.presentations += 1; userDidEarnRewardHandler() }
}
