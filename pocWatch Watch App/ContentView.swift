//
//  ContentView.swift
//  pocWatch Watch App
//
//  Created by Pedro Canute on 27/10/26.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    var body: some View {
        TabView {
            CaminhadaView()
                .tag(0)
            Agua()
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
}
