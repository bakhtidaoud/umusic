package com.example.umusic

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "downloader_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    val savePath = call.argument<String>("savePath")
                    // Implementation would call yt-dlp binary
                    result.success("Download started for: $url")
                }
                "pauseDownload" -> {
                    val url = call.argument<String>("url")
                    // Implementation would pause the process
                    result.success("Download paused for: $url")
                }
                "resumeDownload" -> {
                    val url = call.argument<String>("url")
                    // Implementation would resume the process
                    result.success("Download resumed for: $url")
                }
                "cancelDownload" -> {
                    val url = call.argument<String>("url")
                    // Implementation would kill the process
                    result.success("Download canceled for: $url")
                }
                "mergeFiles" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")
                    val success = runFFmpeg(listOf("-i", videoPath!!, "-i", audioPath!!, "-c", "copy", outputPath!!))
                    if (success) result.success("Merged successfully") else result.error("FFMPEG_ERROR", "Failed to merge", null)
                }
                "runFFmpeg" -> {
                    val args = call.argument<List<String>>("args")
                    val success = runFFmpeg(args!!)
                    if (success) result.success("FFmpeg completed") else result.error("FFMPEG_ERROR", "FFmpeg execution failed", null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun runFFmpeg(args: List<String>): Boolean {
        // Logic to run bundled ffmpeg binary
        // val ffmpegPath = copyBinaryFromAssets("ffmpeg")
        // val process = ProcessBuilder(listOf(ffmpegPath) + args).start()
        // return process.waitFor() == 0
        return true // Mocked for now
    }

    private fun copyBinaryFromAssets(name: String): String {
        val file = File(filesDir, name)
        if (!file.exists()) {
            assets.open(name).use { input ->
                FileOutputStream(file).use { output ->
                    input.copyTo(output)
                }
            }
            file.setExecutable(true)
        }
        return file.absolutePath
    }
}
