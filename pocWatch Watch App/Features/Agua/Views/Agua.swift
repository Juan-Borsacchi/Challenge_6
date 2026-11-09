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
    
    private let totalCopos = 8

    private let quantidadePorRegistro: Double = 250
    
    private var metaDiaria: Double {
        Double(totalCopos) * quantidadePorRegistro
    }
    
    private var coposRegistrados: Int {
        min(max(Int(aguaConsumida / quantidadePorRegistro), 0), totalCopos)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                ForEach(0..<totalCopos, id: \.self) { indice in
                    Circle()
                        .trim(from: CGFloat(indice) / CGFloat(totalCopos) + 0.015,
                              to: CGFloat(indice + 1) / CGFloat(totalCopos) - 0.015)
                        .stroke(indice < coposRegistrados ? Color.blue : Color.blue.opacity(0.2),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.35), value: coposRegistrados)
                        .allowsHitTesting(false)
                }
                
                Button {
                    Task {
                        await registrar()
                    }
                } label: {
                    VStack(spacing: 4) {
                        if registrando {
                            ProgressView()
                                .tint(.blue)
                                .frame(height: 22)
                        } else {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(height: 22)
                        }

                        if aguaConsumida > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(aguaConsumida.formatted(.number.precision(.fractionLength(0))))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text("mL")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text("\((metaDiaria).formatted()) ml")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text("Registrar\nágua")
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(8)
                    .frame(width: 112, height: 112)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.blue.opacity(0.15)), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .animation(.easeInOut(duration: 0.25), value: aguaConsumida)
                .disabled(registrando)
                
            }
            .frame(width: 140, height: 140)

            if registrando {
                Text("Registrando…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Label("250 mL por toque", systemImage: "plus.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        
    }
    
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
