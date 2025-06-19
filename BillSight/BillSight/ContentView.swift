//
//  ContentView.swift
//  BillSight
//
//  Created by Student on 6/14/25.
//

import SwiftUI
import UIKit

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {

    // Creates UIKit ViewController
    func makeUIViewController(context: Context) -> ViewController {
        return ViewController() // Instantiate your ViewController
    }

    // Updates UIKit ViewController
    // Currently does not need more code
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
    }
}

struct ContentView: View {
    var body: some View {
        // Embed UIViewControllerRepresentable here
        CameraViewControllerRepresentable()
            .edgesIgnoringSafeArea(.all) // Fill the screen sntirely
    }
}


#Preview {
    ContentView()
}
