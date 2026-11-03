//
//  Untitled.swift
//  pocWatch
//
//  Created by Pedro Canute on 03/11/26.
//
import SwiftUI
import HealthKit

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
                let valorFormatado = valor.formatted(.number.precision(.fractionLength(1)))
                let dataFormatada = amostra.endDate.formatted()
                
                texto = "\(valorFormatado) dB(A) em \(dataFormatada)"
                
                print("Exposição sonora: \(valor) dB(A)")
                print("Data da medição: \(amostra.endDate)")
                print("Medição: \(amostra.endDate.formatted())")
                print("Agora: \(Date().formatted())")
            } else {
                texto = "Nenhuma amostra disponível"
            }
            
        } catch {
            print("Falha ao solicitar autorização: \(error)")
        }
    }
}
