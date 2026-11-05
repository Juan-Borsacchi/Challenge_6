import SwiftUI

struct ResumoCaminhadaView: View {
    let salvo: Bool
    let inicio: Date
    let duracao: String
    let passos: Int?
    let calorias: Double?
    let bpmMedio: Int?
    let elevacaoMaxima: Double?
    let salvar: () -> Void
    let descartar: () -> Void
    let novaCaminhada: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: salvo ? "checkmark.circle.fill" : "figure.walk.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text(salvo ? "Treino salvo!" : "Caminhada concluída")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                if salvo {
                    Text("Registrado no Saúde")
                        .foregroundStyle(.green)
                } else {
                    Text("Iniciado em: \(inicio, format: .dateTime.day().month(.abbreviated).hour().minute())")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            .frame(maxWidth: .infinity)

            VStack(spacing: 5) {
                Label("Duração total", systemImage: "stopwatch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(duracao)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.quaternary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.green.opacity(0.2), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                metrica("Passos", valor: passos?.formatted(),icone: "shoeprints.fill", cor: .green)
                
                Divider().padding(.horizontal, 24)
                
                metrica("Energia ativa", valor: calorias?.formatted(.number.precision(.fractionLength(0))),unidade: "kcal", icone: "flame.fill", cor: .orange)
                
                Divider().padding(.horizontal, 24)
                
                metrica("Batimentos médios", valor: bpmMedio?.formatted(),unidade: "BPM", icone: "heart.fill", cor: .pink)
                
                Divider().padding(.horizontal, 24)
                
                metrica("Elevação máxima", valor: elevacaoMaxima?.formatted(.number.precision(.fractionLength(0))), unidade: "m", icone: "mountain.2.fill", cor: .cyan)
            }
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.quaternary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.green.opacity(0.2), lineWidth: 1)
            }

            VStack(spacing: 8) {
                if salvo {
                    Button(action: novaCaminhada) {
                        Label("Nova caminhada", systemImage: "figure.walk")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                } else {
                    Button(action: salvar) {
                        Label("Salvar no Saúde", systemImage: "heart.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)

                    Button("Descartar", role: .destructive, action: descartar)
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.footnote)
        }
    }

    private func metrica(_ titulo: String, valor: String?, unidade: String = "", icone: String, cor: Color) -> some View {
        
        HStack(spacing: 10) {
            Image(systemName: icone)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(cor)
                .frame(width: 28, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let valor {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(valor)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        if !unidade.isEmpty {
                            Text(unidade)
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(cor)
                } else {
                    Text("Indisponível")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Resumo") {
    ScrollView {
        ResumoCaminhadaView(
            salvo: false, inicio: .now, duracao: "24:38",
            passos: 2486, calorias: 138, bpmMedio: 112, elevacaoMaxima: 12,
            salvar: {}, descartar: {}, novaCaminhada: {}
        )
        .buttonStyle(.borderedProminent)
        .padding()
    }
}

#Preview("Salvo · sem leituras") {
    ScrollView {
        ResumoCaminhadaView(
            salvo: true, inicio: .now, duracao: "00:12",
            passos: nil, calorias: nil, bpmMedio: nil, elevacaoMaxima: nil,
            salvar: {}, descartar: {}, novaCaminhada: {}
        )
        .buttonStyle(.borderedProminent)
        .padding()
    }
}
