//
//  Agua.swift
//  pocWatch
//
//  Created by Pedro Canute on 03/11/26.
//

import SwiftUI
import HealthKit

struct Agua: View {
    
    @State var healthStore = HKHealthStore()
    @State private var aguaConsumida: Double = 0
    @State private var registrando = false
    @State private var registrou = false
    
    private let totalCopos = 8

    private let quantidadePorRegistro: Double = 250
    
    private var metaDiaria: Double {
        Double(totalCopos) * quantidadePorRegistro
    }
    
    private var coposRegistrados: Int {
        min(max(Int(aguaConsumida / quantidadePorRegistro), 0), totalCopos)
    }
    
    var body: some View {
        VStack (spacing: 12){
            ZStack {
                ForEach(0..<totalCopos, id: \.self) { indice in
                    Circle()
                        .trim(from: CGFloat(indice) / CGFloat(totalCopos) + 0.015,
                              to: CGFloat(indice + 1) / CGFloat(totalCopos) - 0.015)
                        .stroke(indice < coposRegistrados ? Color.blue : Color.gray.opacity(0.2),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.35), value: coposRegistrados)
                        .allowsHitTesting(false)
                }
                
                Button {
                    Task {
                        await registrar()
                        registrou = true
                    }
                } label: {
                    if registrou {
                        VStack{
                            Image(systemName: "drop.halffull")
                                .font(.title2)
                            Text("\(aguaConsumida.formatted())")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(metaDiaria.formatted()) ml")
                                .font(.caption2)
                        }
                        .frame(width: 90, height: 90)
                        .contentShape(Circle())
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "drop.halffull")
                                .font(.title2)
                            Text("Registrar água")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 90, height: 90)
                        .contentShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: Circle())
                .disabled(registrando)
                
            }
            .frame(width: 120, height: 120)
            
        }
        .padding()
        
    }
    
    
    @MainActor
    private func registrar() async {
        guard !registrando else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit indisponível")
            return
        }
        
        registrando = true
        defer { registrando = false }
        
        let tipoAgua = HKQuantityType(.dietaryWater)
        
        do {
            
            try await healthStore.requestAuthorization(toShare: [tipoAgua], read: [])
            let quantidade = HKQuantity(unit: .literUnit(with: .milli), doubleValue: quantidadePorRegistro)
            
            let agora = Date()
            let amostraAgua = HKQuantitySample(type: tipoAgua, quantity: quantidade, start: agora, end: agora, metadata: [HKMetadataKeyWasUserEntered: true])
            
            try await healthStore.save(amostraAgua)
            aguaConsumida += quantidadePorRegistro
            
            
            print("Água registrada: 250ml")
            
        } catch {
            
            print("Falha ao solicitar autorização: \(error)")
        }
    }
}

#Preview {
    Agua()
}
