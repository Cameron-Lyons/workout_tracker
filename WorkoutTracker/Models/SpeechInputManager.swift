import AVFoundation
import Foundation
import Speech

enum SpeechInputError: LocalizedError {
    case unavailable
    case permissionsDenied
    case failedToStart

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Speech recognition is not currently available on this device."
        case .permissionsDenied:
            return "Microphone and speech recognition permissions are required."
        case .failedToStart:
            return "Could not start audio capture. Please try again."
        }
    }
}

final class SpeechInputManager: NSObject, ObservableObject {
    private enum Constants {
        static let audioInputBus = 0
        static let audioTapBufferSize: AVAudioFrameCount = 1024
    }

    @Published private(set) var isRecording = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    deinit {
        stopRecording()
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            }

            return
        }
    }

    func startRecording(updateHandler: @escaping (String, Bool) -> Void) throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechInputError.unavailable
        }

        stopRecording()

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechInputError.failedToStart
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        self.recognitionRequest = recognitionRequest

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: Constants.audioInputBus)

        inputNode.removeTap(onBus: Constants.audioInputBus)
        inputNode.installTap(
            onBus: Constants.audioInputBus,
            bufferSize: Constants.audioTapBufferSize,
            format: inputFormat
        ) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            stopRecording()
            throw SpeechInputError.failedToStart
        }

        DispatchQueue.main.async {
            self.isRecording = true
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                DispatchQueue.main.async {
                    updateHandler(result.bestTranscription.formattedString, result.isFinal)
                }

                if result.isFinal {
                    self.stopRecording()
                }
            }

            if error != nil {
                self.stopRecording()
            }
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: Constants.audioInputBus)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
