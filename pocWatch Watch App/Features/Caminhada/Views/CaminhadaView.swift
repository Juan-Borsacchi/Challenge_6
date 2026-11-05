import SwiftUI

struct CaminhadaView: View {
    @StateObject private var treino = CaminhadaStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if treino.estado == .pronto {
                    Label("Caminhada", systemImage: "figure.walk")
                        .foregroundStyle(.green)
                }

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
                    CaminhandoView(inicio: treino.inicio,bpm: treino.bpm,passos: treino.passos,calorias: treino.calorias,elevacaoMaxima: treino.altitudeInicial == nil || treino.erroAltitude != nil ? nil : treino.elevacaoMaxima,encerrar: { treino.encerrar() })

                case .resumo, .salvo:
                    ResumoCaminhadaView(salvo: treino.estado == .salvo,inicio: treino.inicio,duracao: treino.tempoFormatado,passos: treino.passos,calorias: treino.calorias,bpmMedio: treino.bpmMedio,elevacaoMaxima: treino.altitudeInicial == nil || treino.erroAltitude != nil ? nil : treino.elevacaoMaxima,salvar: { Task { await treino.salvar() } }, descartar: { treino.descartar() },novaCaminhada: { treino.reiniciar() })
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

                if let erroAltitude = treino.erroAltitude,
                   treino.estado == .resumo || treino.estado == .salvo {
                    Text(erroAltitude)
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
