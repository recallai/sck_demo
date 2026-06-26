import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = Recorder()
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 16) {
            Button(isRecording ? "Stop Capture" : "Start Capture") {
                Task {
                    if isRecording {
                        await recorder.stop()
                        isRecording = false
                    } else {
                        do {
                            try await recorder.start()
                            isRecording = true
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
