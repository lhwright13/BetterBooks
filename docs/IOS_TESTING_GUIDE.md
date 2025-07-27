# Testing an iOS App Locally

This short guide explains how to create a minimal iOS app in Xcode and run it on your iPhone without publishing to the App Store.

## 1. Create a new Xcode project

1. Launch **Xcode** and choose **File → New → Project**.
2. Select **App** under the iOS tab and click **Next**.
3. Enter a **Product Name** (e.g., `HelloApp`) and choose **Swift** as the language.
4. Select **Storyboard** or **SwiftUI** for the user interface (either works for testing).
5. Save the project in any directory.

At this point Xcode generates a basic app template with a single view. You can build and run it using the iOS Simulator by pressing `Cmd+R`.

## 2. Add a simple interface

Open `ContentView.swift` (for SwiftUI) or `ViewController.swift` (for UIKit) and replace the default content with a simple label:

### SwiftUI
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, iOS!")
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

### UIKit
```swift
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let label = UILabel()
        label.text = "Hello, iOS!"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

Build and run the project in the simulator to verify it displays "Hello, iOS!".

## 3. Run the app on your iPhone

You do not need to publish on the App Store to test on a physical device. With Xcode installed and an Apple ID, you can deploy directly to your iPhone:

1. Connect your iPhone to your Mac via USB.
2. Unlock the device and choose it from the device dropdown in Xcode (next to the run button).
3. The first time you use a new device, Xcode will ask to register it for development. Allow it to manage your signing certificate with your Apple ID.
4. Press `Cmd+R` to build and run. Xcode signs the app with a temporary profile and installs it on your iPhone.

The app will appear on your home screen and you can launch it like any other app. Because it is signed with a personal development certificate, it will remain valid for a few days. You can reinstall or rebuild at any time.

For longer-term testing or sharing with testers, you can create an archive in Xcode and distribute it via TestFlight or a signed IPA file, both of which still avoid publishing publicly on the App Store.


