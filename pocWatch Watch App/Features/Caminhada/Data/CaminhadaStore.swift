import Foundation
import Combine
import HealthKit
import CoreMotion

@MainActor
class CaminhadaStore: NSObject, ObservableObject {
    enum Estado {
        case pronto, caminhando, resumo, salvo
    }

    @Published private(set) var estado: Estado = .pronto
    @Published private(set) var carregando = false
    @Published private(set) var bpm: Int?
    @Published private(set) var bpmMedio: Int?
    @Published private(set) var calorias: Double?
    @Published private(set) var passos: Int?
    @Published private(set) var erroPassos: String?
    @Published private(set) var inicio = Date()
    @Published private(set) var duracao: TimeInterval = 0
    @Published private(set) var erro: String?

    private let healthStore = HKHealthStore()
    private let pedometro = CMPedometer()
    private var sessao: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var tempoFormatado: String {
        let segundos = Int(duracao)
        return String(format: "%02d:%02d", segundos / 60, segundos % 60)
    }

    func iniciar() async {
        guard estado == .pronto, !carregando else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            erro = "HealthKit indisponível."
            return
        }
        carregando = true
        erro = nil
        defer { carregando = false }

        do {
            try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()],read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])

            guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
                erro = "Permita salvar treinos no Saúde para iniciar."
                return
            }

            // A sessão configura os sensores para uma caminhada interna.
            let configuracao = HKWorkoutConfiguration()
            configuracao.activityType = .walking
            configuracao.locationType = .indoor

            let novaSessao = try HKWorkoutSession(healthStore: healthStore, configuration: configuracao)
            let novoBuilder = novaSessao.associatedWorkoutBuilder()
            sessao = novaSessao
            builder = novoBuilder
            novaSessao.delegate = self
            novoBuilder.delegate = self
            novoBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuracao)

            inicio = Date()
            novaSessao.startActivity(with: inicio)
            try await novoBuilder.beginCollection(at: inicio)
            guard sessao === novaSessao else { return }
            estado = .caminhando
            iniciarPassos()
        } catch {
            tratarFalha(error)
        }
    }

    func encerrar() {
        guard estado == .caminhando, !carregando else { return }
        carregando = true
        pedometro.stopUpdates()
        sessao?.end()

    }

    private func prepararResumo(em data: Date) async {
        guard let builder else { return }
        pedometro.stopUpdates()
        carregando = true
        defer { carregando = false }
        do {
            try await builder.endCollection(at: data)
            guard self.builder === builder else { return }
            atualizarMetricas()
            duracao = builder.elapsedTime(at: data)
            estado = .resumo
            consultarPassosFinais(ate: data)
        } catch {
            tratarFalha(error)
        }
    }

    func salvar() async {
        guard estado == .resumo, !carregando, let builder else { return }
        carregando = true
        erro = nil
        defer { carregando = false }
        do {
            guard try await builder.finishWorkout() != nil else {
                erro = "O Saúde não confirmou o salvamento."
                return
            }
            liberarSessao()
            estado = .salvo
        } catch {
            erro = "Não foi possível salvar: \(error.localizedDescription)"
        }
    }

    func descartar() {
        guard estado == .resumo, !carregando else { return }
        builder?.discardWorkout()
        reiniciar()
    }

    func reiniciar() {
        guard estado == .resumo || estado == .salvo else { return }
        limparTreino()
    }

    private func atualizarMetricas() {
        guard let builder else { return }
        let unidadeBPM = HKUnit.count().unitDivided(by: .minute())
        let batimentos = builder.statistics(for: HKQuantityType(.heartRate))
        if let valor = batimentos?.mostRecentQuantity()?.doubleValue(for: unidadeBPM) {
            bpm = Int(valor.rounded())
        }
        if let media = batimentos?.averageQuantity()?.doubleValue(for: unidadeBPM) {
            bpmMedio = Int(media.rounded())
        }
        calorias = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    private func iniciarPassos() {
        guard CMPedometer.isStepCountingAvailable() else {
            erroPassos = "Contagem de passos indisponível neste dispositivo."
            return
        }
        let inicioDaContagem = inicio
        pedometro.startUpdates(from: inicioDaContagem) { [weak self] dados, error in
            Task { @MainActor in
                guard let self, self.inicio == inicioDaContagem,
                      self.estado == .caminhando, !self.carregando else { return }
                if let error {
                    self.erroPassos = "Passos indisponíveis: \(error.localizedDescription)"
                } else if let dados {
                    // O pedômetro já retorna o total desde o início; não somamos novamente.
                    self.passos = dados.numberOfSteps.intValue
                    self.erroPassos = nil
                }
            }
        }
    }

    private func consultarPassosFinais(ate fim: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let inicioDaContagem = inicio
        // Consulta apenas o intervalo do treino, sem incluir passos após o encerramento.
        pedometro.queryPedometerData(from: inicioDaContagem, to: fim) { [weak self] dados, error in
            Task { @MainActor in
                guard let self, self.inicio == inicioDaContagem,
                      self.estado == .resumo || self.estado == .salvo else { return }
                if let error {
                    self.erroPassos = "Passos indisponíveis: \(error.localizedDescription)"
                } else if let dados {
                    self.passos = dados.numberOfSteps.intValue
                    self.erroPassos = nil
                }
            }
        }
    }

    private func liberarSessao() {
        pedometro.stopUpdates()
        sessao?.delegate = nil
        builder?.delegate = nil
        sessao = nil
        builder = nil
    }

    private func limparTreino() {
        liberarSessao()
        bpm = nil
        bpmMedio = nil
        calorias = nil
        passos = nil
        erroPassos = nil
        duracao = 0
        erro = nil
        estado = .pronto
    }

    private func tratarFalha(_ error: Error) {
        sessao?.delegate = nil
        sessao?.end()
        builder?.discardWorkout()
        limparTreino()
        carregando = false
        erro = "O treino foi interrompido: \(error.localizedDescription)"
    }
}

// Os delegates são os avisos do HealthKit sobre a sessão e as novas medições.
extension CaminhadaStore: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            guard self.sessao === workoutSession else { return }
            if toState == .ended {
                await self.prepararResumo(em: date)
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.sessao === workoutSession else { return }
            self.tratarFalha(error)
        }
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                   didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            guard self.builder === workoutBuilder else { return }
            self.atualizarMetricas()
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}
