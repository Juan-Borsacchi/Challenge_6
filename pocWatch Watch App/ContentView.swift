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
            Decibel()
                .tag(0)
            Agua()
                .tag(1)
        }
    }
}

struct Decibel: View {
    @State var texto: String = "Toque para consultar"
    @State var healthStore = HKHealthStore()
    var body: some View {
        VStack {
            Text(texto)
            Button {
                Task {
                    await consultar()
                }
            } label: {
                Image(systemName: "ear.badge.waveform")
                Text("Consultar ruído")
            }
            .glassEffect()
        }
        .padding()
    }
    
    private func consultar() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        let tipoRuido = HKQuantityType(.environmentalAudioExposure)
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [tipoRuido])
            
            let consulta = HKSampleQueryDescriptor(predicates: [.quantitySample(type: tipoRuido)], sortDescriptors: [SortDescriptor(\HKQuantitySample.endDate, order: .reverse)], limit: 1)
            
            let amostras = try await consulta.result(for: healthStore)
            
            print("Quantidade de amostras: \(amostras.count)")
            
            if let amostra = amostras.first {
                let valor = amostra.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
                print("Exposição sonora: \(valor) dB(A)")
                print("Data da medição: \(amostra.endDate)")
                print("Medição: \(amostra.endDate.formatted())")
                print("Agora: \(Date().formatted())")
            }
            
        } catch {
            print("Falha ao solicitar autorização: \(error)")
        }
    }
}

struct Agua: View {
    @State var texto: String = "Toque para consultar"
    @State var healthStore = HKHealthStore()
    var body: some View {
        VStack {
            Text(texto)
            Button {
                Task {
                    await registrar()
                }
            } label: {
                Image(systemName: "drop.halffull")
                Text("Registrar água")
            }
            .glassEffect()
        }
        .padding()
    }
    
    private func registrar() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            return print("Falha ao acessar o healthKit")
        }
        
        let tipoAgua = HKQuantityType(.dietaryWater)
        
        do {
            
            try await healthStore.requestAuthorization(toShare: [tipoAgua], read: [])
            let quantidade = HKQuantity(unit: .literUnit(with: .milli), doubleValue: 250)
            
            let agora = Date()
            let amostraAgua = HKQuantitySample(type: tipoAgua, quantity: quantidade, start: agora, end: agora, metadata: [HKMetadataKeyWasUserEntered: true])
            
            try await healthStore.save(amostraAgua)
            print("Água registrada: 200ml")
            
        } catch {
            print("Falha ao solicitar autorização: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
