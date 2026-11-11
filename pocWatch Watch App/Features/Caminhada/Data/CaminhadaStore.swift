import Foundation
import Combine
import HealthKit
import CoreMotion

// Cuida apenas da sessão, dos sensores e dos resultados coletados.
// Os estados da tela e o carregamento ficam na CaminhadaViewModel.
class CaminhadaStore: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published private(set) var dados = DadosCaminhada()
    private var caminhando = false
    private let healthStore = HKHealthStore()
    private let pedometro = CMPedometer()
    private let altimetro = CMAltimeter()
    private var sessao: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var leituraAltitudeID: UUID?

    // Erros que a ViewModel pode apresentar na tela.
    private enum Falha: LocalizedError {
        case healthKitIndisponivel, permissaoNegada, encerramentoNaoConfirmado, salvamentoNaoConfirmado

        var errorDescription: String? {
            switch self {
            case .healthKitIndisponivel:
                return "HealthKit indisponível."
            case .permissaoNegada:
                return "Permita salvar treinos no Saúde para iniciar."
            case .encerramentoNaoConfirmado:
                return "O Saúde não confirmou o encerramento do treino."
            case .salvamentoNaoConfirmado:
                return "O Saúde não confirmou o salvamento."
            }
        }
    }

    /// Solicita permissão e inicia uma caminhada interna.
    func iniciar() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw Falha.healthKitIndisponivel
        }

        try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()],read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
        
        guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            throw Falha.permissaoNegada
        }

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

        dados = DadosCaminhada()
        novaSessao.startActivity(with: dados.inicio)

        try await novoBuilder.beginCollection(at: dados.inicio)

        // Se a sessão falhou durante a espera, não inicia os sensores.
        guard sessao === novaSessao else { throw CancellationError() }
        caminhando = true

        iniciarPassos()
        registrarAltitude(inicial: true)
    }

    /// Para as leituras e solicita o encerramento ao HealthKit.
    func encerrar() {
        guard caminhando else { return }
        caminhando = false
        pedometro.stopUpdates()

        registrarAltitude(inicial: false)

        sessao?.end() //verifica se sessao possui um objeto, se tiver chama o metodo .end() do workout
    }

    /// Salva o treino; se falhar, mantém a coleta disponível para tentar novamente.
    func salvar() async throws {
        guard let builder else { throw CancellationError() }
        let treinoSalvo = try await builder.finishWorkout()
        guard self.builder === builder else { throw CancellationError() }
        guard treinoSalvo != nil else { throw Falha.salvamentoNaoConfirmado }
        limparTreino(manterResultados: true)
    }

    /// Descarta a coleta e deixa os sensores prontos para outra caminhada.
    func descartar() {
        sessao?.delegate = nil
        sessao?.end()
        builder?.discardWorkout()
        limparTreino()
    }

    /// Lê os batimentos e as calorias já reunidos pelo HealthKit.
    private func atualizarMetricas() {
        guard let builder else { return }
        let unidadeBPM = HKUnit.count().unitDivided(by: .minute())
        let batimentos = builder.statistics(for: HKQuantityType(.heartRate))

        if let valor = batimentos?.mostRecentQuantity()?.doubleValue(for: unidadeBPM) {
            dados.bpm = Int(valor.rounded())
        }
        if let media = batimentos?.averageQuantity()?.doubleValue(for: unidadeBPM) {
            dados.bpmMedio = Int(media.rounded())
        }
        dados.calorias = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    /// Acompanha os passos desde o início da caminhada.
    private func iniciarPassos() {
        guard CMPedometer.isStepCountingAvailable() else {
            dados.erroPassos = "Contagem de passos indisponível neste dispositivo."
            return
        }

        let inicioDaContagem = dados.inicio
        pedometro.startUpdates(from: inicioDaContagem) { dados, erro in
            let passos = dados?.numberOfSteps.intValue
            let mensagemErro = erro?.localizedDescription
            OperationQueue.main.addOperation {
                guard self.dados.inicio == inicioDaContagem, self.caminhando else { return }
                self.atualizarPassos(passos, erro: mensagemErro)
            }
        }
    }

    /// Confere o total de passos entre o início e o encerramento.
    private func consultarPassosFinais(ate fim: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let inicioDaContagem = dados.inicio

        pedometro.queryPedometerData(from: inicioDaContagem, to: fim) { dados, erro in
            let passos = dados?.numberOfSteps.intValue
            let mensagemErro = erro?.localizedDescription
            OperationQueue.main.addOperation {
                guard self.dados.inicio == inicioDaContagem, !self.caminhando else { return }
                self.atualizarPassos(passos, erro: mensagemErro)
            }
        }
    }

    private func atualizarPassos(_ passos: Int?, erro: String?) {
        if let erro {
            dados.erroPassos = "Passos indisponíveis: \(erro)"
        } else if let passos {
            dados.passos = passos
            dados.erroPassos = nil
        }
    }

    /// Guarda o ponto inicial e acompanha a subida, ou faz a última leitura.
    private func registrarAltitude(inicial: Bool) {
        altimetro.stopAbsoluteAltitudeUpdates()
        leituraAltitudeID = nil
        dados.erroAltitude = nil

        guard CMAltimeter.isAbsoluteAltitudeAvailable() else {
            dados.erroAltitude = "Não foi possível iniciar o altímetro"
            return
        }
 
        // O identificador permite ignorar respostas de uma leitura que já foi cancelada.
        let pedidoID = UUID()
        leituraAltitudeID = pedidoID

        altimetro.startAbsoluteAltitudeUpdates(to: .main) { dados, erro in
            let altitude = dados?.altitude
            let mensagemErro = erro?.localizedDescription

            guard self.leituraAltitudeID == pedidoID else { return }
            if let mensagemErro {
                self.altimetro.stopAbsoluteAltitudeUpdates()
                self.leituraAltitudeID = nil
                self.dados.erroAltitude = mensagemErro
                return
            }
            guard let altitude else { return }

            self.dados.altitudeAtual = altitude
            if !inicial {
                self.dados.altitudeFinal = altitude
                self.altimetro.stopAbsoluteAltitudeUpdates()
                self.leituraAltitudeID = nil
            } else if self.dados.altitudeInicial == nil {
                self.dados.altitudeInicial = altitude
            }

            if let pontoInicial = self.dados.altitudeInicial {
                self.dados.elevacaoMaxima = max(self.dados.elevacaoMaxima, altitude - pontoInicial)
            }
        }
    }

    /// Libera os recursos. Após salvar, preserva os resultados do resumo.
    private func limparTreino(manterResultados: Bool = false) {
        caminhando = false
        pedometro.stopUpdates()
        sessao?.delegate = nil
        builder?.delegate = nil
        sessao = nil
        builder = nil

        if manterResultados { return }

        altimetro.stopAbsoluteAltitudeUpdates()
        leituraAltitudeID = nil
        dados = DadosCaminhada()
    }

    private func tratarFalha(_ erro: Error) {
        descartar()
        dados.erro = "O treino foi interrompido: \(erro.localizedDescription)"
    }

    /// Finaliza os resultados depois que o HealthKit confirma o encerramento.
    private func finalizarColeta(da sessaoEncerrada: HKWorkoutSession, em data: Date) {
        guard sessao === sessaoEncerrada, let builder else { return }
        caminhando = false
        pedometro.stopUpdates()

        builder.endCollection(withEnd: data) { sucesso, erro in
            OperationQueue.main.addOperation {
                guard self.builder === builder else { return }
                guard sucesso else {
                    self.tratarFalha(erro ?? Falha.encerramentoNaoConfirmado)
                    return
                }

                self.atualizarMetricas()
                self.dados.duracao = builder.elapsedTime(at: data)
                self.dados.terminou = true
                self.consultarPassosFinais(ate: data)
            }
        }
    }

    // Os retornos do HealthKit chegam em segundo plano. A tela observa os dados na fila principal.
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        OperationQueue.main.addOperation {
            self.finalizarColeta(da: workoutSession, em: date)
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        OperationQueue.main.addOperation {
            guard self.sessao === workoutSession else { return }
            self.tratarFalha(error)
        }
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        OperationQueue.main.addOperation {
            guard self.builder === workoutBuilder else { return }
            self.atualizarMetricas()
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}
