import UIKit
import Flutter

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let flutterEngine = appDelegate.flutterEngine

        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        let win = UIWindow(windowScene: windowScene)
        win.rootViewController = flutterViewController
        win.makeKeyAndVisible()
        self.window = win
    }
}
