//
//  ContentView.swift
//  BillSight
//
//  Created by Student on 6/14/25.
//

import SwiftUI
import UIKit // Important: Make sure to import UIKit

// Replace 'ViewController' with the actual name of your UIViewController class
struct CameraViewControllerRepresentable: UIViewControllerRepresentable {

    // This function creates your UIKit ViewController
    func makeUIViewController(context: Context) -> ViewController {
        return ViewController() // Instantiate your ViewController
    }

    // This function updates your UIKit ViewController
    // For our simple camera app, we don't need to do anything here for now.
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // You might update properties of your ViewController here if needed
    }
}

struct ContentView: View {
    var body: some View {
        // Embed your UIViewControllerRepresentable here
        CameraViewControllerRepresentable()
            .edgesIgnoringSafeArea(.all) // Make it fill the screen
    }
}


#Preview {
    ContentView()
}
