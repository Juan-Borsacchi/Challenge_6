import SwiftUI

struct CaminhandoView: View {
    let inicio: Date
    let bpm: Int?
    let passos: Int?
    let calorias: Double?
    let elevacaoMaxima: Double?
    let encerrar: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Label("Caminhada", systemImage: "figure.walk")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)

                Text("Em andamento")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 5) {
                Label("Tempo decorrido", systemImage: "stopwatch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(inicio, style: .timer)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
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

            VStack(spacing: 0) {
                metrica("Batimentos", valor: bpm?.formatted(),
                        unidade: "BPM", icone: "heart.fill", cor: .pink)

                Divider().padding(.horizontal, 24)

                metrica("Passos", valor: passos?.formatted(),
                        icone: "shoeprints.fill", cor: .green)

                Divider().padding(.horizontal, 24)

                metrica("Energia ativa", valor: calorias?.formatted(.number.precision(.fractionLength(0))),
                        unidade: "kcal", icone: "flame.fill", cor: .orange)
                
                Divider().padding(.horizontal, 24)

                metrica("Elevação máxima",valor: elevacaoMaxima?.formatted(.number.precision(.fractionLength(0))),unidade: "m",icone: "mountain.2.fill",cor: .cyan)
            }
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.quaternary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.green.opacity(0.2), lineWidth: 1)
            }

            Button(role: .destructive, action: encerrar) {
                Text("Encerrar")
                    .frame(maxWidth: .infinity)
            }
            .font(.footnote)
            .tint(.red)
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
                    Text("0")
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

#Preview("Caminhando") {
    ScrollView {
        CaminhandoView(inicio: .now.addingTimeInterval(-1480),bpm: 112, passos: 2486, calorias: 138, elevacaoMaxima: 2,encerrar: {})
        .buttonStyle(.borderedProminent)
        .padding()
    }
}
