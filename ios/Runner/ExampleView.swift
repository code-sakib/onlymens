// ExampleView.swift
import SwiftUI
import FamilyControls

// Define a protocol to communicate with the UIKit/Flutter layer.
protocol ExampleViewDelegate: AnyObject {
    func didUpdateSelection(selection: FamilyActivitySelection)
}

struct ExampleView: View {
    @State var selection = FamilyActivitySelection()
    weak var delegate: ExampleViewDelegate? // Weak reference to avoid memory leaks

    var body: some View {
        VStack {
            Image(systemName: "eye")
                .font(.system(size: 76.0))
                .padding()

            FamilyActivityPicker(selection: $selection)

            Image(systemName: "hourglass")
                .font(.system(size: 76.0))
                .padding()
        }
        .onChange(of: selection) { newSelection in


            // ✅ Pass the updated selection to the delegate
            delegate?.didUpdateSelection(selection: newSelection)
        }
    }
}
