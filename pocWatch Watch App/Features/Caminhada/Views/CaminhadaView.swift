import SwiftUI

struct CaminhadaView: View {
    @StateObject private var viewModel = CaminhadaViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.estado == .pronto {
                    Label("Caminhada", systemImage: "figure.walk")
                        .foregroundStyle(.green)
                }

                switch viewModel.estado {
                case .pronto:
                    Text("Acompanhe seus passos e batimentos.")
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    Button("Iniciar") {
                        Task { await viewModel.iniciar() }
                    }
                    .tint(.green)

                case .caminhando:
                    CaminhandoView(
                        inicio: viewModel.dados.inicio,
                        bpm: viewModel.dados.bpm,
                        passos: viewModel.dados.passos,
                        calorias: viewModel.dados.calorias,
                        elevacaoMaxima: viewModel.elevacaoMaxima,
                        encerrar: { viewModel.encerrar() }
                    )

                case .resumo, .salvo:
                    ResumoCaminhadaView(
                        salvo: viewModel.estado == .salvo,
                        inicio: viewModel.dados.inicio,
                        duracao: viewModel.tempoFormatado,
                        passos: viewModel.dados.passos,
                        calorias: viewModel.dados.calorias,
                        bpmMedio: viewModel.dados.bpmMedio,
                        elevacaoMaxima: viewModel.elevacaoMaxima,
                        salvar: { Task { await viewModel.salvar() } },
                        descartar: { viewModel.descartar() },
                        novaCaminhada: { viewModel.reiniciar() }
                    )
                }

                if viewModel.carregando {
                    ProgressView()
                }

                if let erro = viewModel.erro {
                    Text(erro)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let erroPassos = viewModel.dados.erroPassos {
                    Text(erroPassos)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let erroAltitude = viewModel.dados.erroAltitude,
                   viewModel.estado == .resumo || viewModel.estado == .salvo {
                    Text(erroAltitude)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.carregando)
            .padding()
        }
    }
}

#Preview {
    CaminhadaView()
}
