import Foundation
import ScreenCaptureKit
import Combine
import CoreMedia
import AVFoundation

@MainActor
final class Recorder: NSObject, ObservableObject {
    var stream: SCStream?
    let output = StreamOutput()

    func start() async throws {
        let outputURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Movies")
            .appendingPathComponent("meeting-recording.mov")

        let outputFolder = outputURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: outputFolder,
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        print("Saving to: \(outputURL.path)")

        output.startWriting(to: outputURL)

        let content = try await SCShareableContent.current

        guard let display = content.displays.first else {
            print("No display found")
            return
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.width = 1920
        config.height = 1080
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.capturesAudio = true
        config.captureMicrophone = true
        config.microphoneCaptureDeviceID = nil
        let stream = SCStream(
            filter: filter,
            configuration: config,
            delegate: nil
        )

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue.main)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: DispatchQueue.main)
        try stream.addStreamOutput(output, type: .microphone, sampleHandlerQueue: DispatchQueue.main)

        try await stream.startCapture()

        self.stream = stream
        print("Capture started")
    }

    func stop() async {
        do {
            try await stream?.stopCapture()
            stream = nil
            output.finishWriting()
            print("Capture stopped")
        } catch {
            print("Stop failed:", error)
        }
    }
}

final class StreamOutput: NSObject, SCStreamOutput {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var hasStartedSession = false
    private var isFinishing = false

    func startWriting(to url: URL) {
        do {
            hasStartedSession = false
            isFinishing = false

            writer = try AVAssetWriter(outputURL: url, fileType: .mov)

            let videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1920,
                    AVVideoHeightKey: 1080
                ]
            )
            videoInput.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: 1920,
                    kCVPixelBufferHeightKey as String: 1080
                ]
            )

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128000
            ]

            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true

            let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            micInput.expectsMediaDataInRealTime = true

            if writer!.canAdd(videoInput) {
                writer!.add(videoInput)
            }

            if writer!.canAdd(audioInput) {
                writer!.add(audioInput)
            }

            if writer!.canAdd(micInput) {
                writer!.add(micInput)
            }

            self.videoInput = videoInput
            self.audioInput = audioInput
            self.micInput = micInput
            self.pixelBufferAdaptor = adaptor

            writer!.startWriting()
        } catch {
            print("Failed to start writer:", error)
        }
    }

    func finishWriting() {
        guard !isFinishing else { return }
        isFinishing = true

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        micInput?.markAsFinished()

        writer?.finishWriting {
            if let error = self.writer?.error {
                print("Writer failed:", error)
            } else {
                print("Finished writing:", self.writer?.outputURL.path ?? "")
            }
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard !isFinishing else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let writer = writer else { return }
        guard writer.status == .writing || writer.status == .unknown else { return }

        switch outputType {
        case .screen:
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if !hasStartedSession {
                writer.startSession(atSourceTime: timestamp)
                hasStartedSession = true
            }

            if videoInput?.isReadyForMoreMediaData == true {
                pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: timestamp)
            }

        case .audio:
            guard hasStartedSession else { return }

            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }

        case .microphone:
            guard hasStartedSession else { return }

            print("microphone buffer received")

            if micInput?.isReadyForMoreMediaData == true {
                let didAppend = micInput?.append(sampleBuffer) ?? false
                if !didAppend {
                    print("Failed to append mic:", writer.error ?? "unknown error")
                }
            }

        @unknown default:
            break
        }
    }
}
