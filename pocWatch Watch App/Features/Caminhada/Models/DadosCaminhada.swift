import Foundation

// Guarda somente os resultados e os avisos dos sensores de uma caminhada.
struct DadosCaminhada {
    var inicio = Date()
    var duracao: TimeInterval = 0
    var bpm: Int?
    var bpmMedio: Int?
    var calorias: Double?
    var passos: Int?
    var erroPassos: String?
    var altitudeInicial: Double?
    var altitudeAtual: Double?
    var altitudeFinal: Double?
    var elevacaoMaxima: Double = 0
    var erroAltitude: String?
    var terminou = false
    var erro: String?
}
