import SwiftUI

struct CaminhadaView: View {
    @StateObject private var treino = CaminhadaStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label("Caminhada", systemImage: "figure.walk")
                    .foregroundStyle(.green)

                switch treino.estado {
                case .pronto:
                    Text("Acompanhe seus batimentos e passos durante uma caminhada interna.")
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    Button("Iniciar") {
                        Task { await treino.iniciar() }
                    }
                    .tint(.green)

                case .caminhando:
                    VStack {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            
                            if let bpm = treino.bpm {
                                Text("\(bpm) BPM")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            } else {
                                Text("Aguardando leitura…")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 20))
                        
                        Text(treino.inicio, style: .timer)
                            .font(.title2)
                            .monospacedDigit()
                        HStack(spacing: 8) {
                            if treino.estado != .pronto {
                                Label {
                                    if let passos = treino.passos {
                                        Text("\(passos) passos")
                                    } else {
                                        Text(treino.erroPassos == nil ? "0 passos" : "Passos indisponíveis")
                                    }
                                } icon: {
                                    Image(systemName: "shoeprints.fill")
                                }
                                .font(.caption2)
                                .foregroundStyle(.green)
                                
                            }
                            
                            if let calorias = treino.calorias {
                                Label("\(Int(calorias)) kcal", systemImage: "flame.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding()
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 20))
                        .padding()
                        
                        Button("Encerrar", role: .destructive) {
                            treino.encerrar()
                        }
                        .tint(.red)
                    }

                case .resumo, .salvo:
                    Text(treino.estado == .salvo ? "Treino salvo!" : "Resumo")
                        .font(.headline)
                    Text("Duração: \(treino.tempoFormatado)")

                    if let media = treino.bpmMedio {
                        Text("Média: \(media) BPM")
                            .foregroundStyle(.pink)
                    }
                    if let passos = treino.passos {
                        Text("\(passos) passos")
                    } else {
                        Text(treino.erroPassos == nil ? "0 passos" : "Passos indisponíveis")
                    }
                    
                    if let caloria = treino.calorias {
                        Text("\(Int(caloria)) kcal")
                    } else {
                        Text(treino.erroPassos == nil ? "0 kcal" : "Calorias indisponíveis")
                    }
                    

                    if treino.estado == .resumo {
                        Button("Salvar no Saúde") {
                            Task { await treino.salvar() }
                        }
                        .tint(.green)

                        Button("Descartar", role: .destructive) {
                            treino.descartar()
                        }
                    } else {
                        Button("Nova caminhada") {
                            treino.reiniciar()
                        }
                    }
                }

                if treino.carregando {
                    ProgressView()
                }

                if let erro = treino.erro {
                    Text(erro)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let erroPassos = treino.erroPassos {
                    Text(erroPassos)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(treino.carregando)
            .padding()
        }
    }
}

#Preview {
    CaminhadaView()
}
