# ScreenCaptureKit Meeting Recorder Demo

A minimal macOS app that records your screen, system audio, and microphone with Apple's ScreenCaptureKit and saves them to a single `.mov` file.

This repo accompanies the blog post [How to use ScreenCaptureKit to capture microphone and meeting audio](https://www.recall.ai/blog/how-to-use-screencapturekit-to-record-a-meeting).

## Demo
https://www.loom.com/share/f9c5ede9b7664f858c6c2910774d5898

## Requirements

- macOS 15 or later (ScreenCaptureKit's microphone capture API requires macOS 15)
- Xcode 26 or later
- An Apple ID signed in to Xcode (a free account is enough to run the app locally)

## Quick start

1. **Clone the repository:**

   ```bash
   git clone https://github.com/recallai/sck_demo.git
   cd sck_demo
   ```

2. **Open the project in Xcode:**

   ```bash
   open MeetingRecorder.xcodeproj
   ```

3. **Set up signing:** select the **MeetingRecorder** target, open **Signing & Capabilities**, and choose your **Team**. If Xcode says the bundle identifier is unavailable, change it to something unique (e.g. `com.yourname.MeetingRecorder`).

4. **Run the app:** press **⌘R**.

5. **Start recording:** click **Start Capture**. The first time, macOS will ask for **Screen & System Audio Recording** and **Microphone** access. Grant both. If macOS asks you to quit and reopen the app after granting screen recording access, stop the app in Xcode, press **⌘R** again, and click **Start Capture**.

6. **Stop recording:** click **Stop Capture**. The recording is saved to:

   ```
   ~/Movies/meeting-recording.mov
   ```

   Each new recording overwrites the previous file.

## What gets recorded

| Track | Source | Format |
| :--- | :--- | :--- |
| Video | Main display, 1920×1080 at 30 fps | H.264 |
| Audio track 1 | System audio (remote participants and any other sound your Mac plays) | AAC |
| Audio track 2 | Microphone | AAC |

Some video players only play the first audio track. To mix system audio and microphone into a single track, run:

```bash
ffmpeg -i ~/Movies/meeting-recording.mov \
  -filter_complex "[0:a:0][0:a:1]amix=inputs=2:duration=longest[a]" \
  -map 0:v:0 -map "[a]" -c:v copy -c:a aac \
  ~/Movies/meeting-recording-mixed.mov
```

## Troubleshooting

**No permission prompt, or capture fails to start:** reset the permissions for the app, then run it again from Xcode:

```bash
tccutil reset ScreenCapture com.joy.MeetingRecorder
tccutil reset Microphone com.joy.MeetingRecorder
```

Replace `com.joy.MeetingRecorder` with your bundle identifier if you changed it.

**Microphone is silent in the recording:** check that the app is enabled in **System Settings > Privacy & Security > Microphone**. While recording, the Xcode console should print `microphone buffer received`.

**"Writer failed" in the Xcode console:** make sure `~/Movies` is writable and that `meeting-recording.mov` isn't open in another app.

## Other desktop recording resources

- [Exploring macOS screen capture APIs and recording approaches](https://www.recall.ai/blog/macos-screencapture-api)
- [Core Audio Taps: a deep dive](https://www.recall.ai/blog/core-audio-taps)
- [How I built a botless recorder for meetings from scratch](https://www.recall.ai/blog/how-i-built-a-botless-meeting-recorder-from-scratch)
- If you need meeting detection, speaker-labeled transcripts, or Windows support, see the [Recall.ai Desktop Recording SDK](https://docs.recall.ai/docs/desktop-sdk) and the [minimal Desktop Recording SDK sample](https://github.com/recallai/minimal_dsdk_sample).

## License

MIT
