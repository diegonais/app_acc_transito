package com.example.app_acc_transito;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognitionSupport;
import android.speech.RecognitionSupportCallback;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final int AUDIO_PERMISSION = 7041;
  private SpeechRecognizer recognizer;
  private boolean capturing;
  private MethodChannel.Result pending;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private final Runnable timeout = () -> finish(null, "timeout");

  @Override
  public void configureFlutterEngine(FlutterEngine engine) {
    super.configureFlutterEngine(engine);
    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),
        "app_acc_transito/dictation").setMethodCallHandler((call, result) -> {
      switch (call.method) {
        case "listen":
          if (pending != null) { result.error("busy", "Dictado en curso", null); return; }
          if (Build.VERSION.SDK_INT < 31 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            result.error("unavailable", "Reconocimiento local no disponible", null); return;
          }
          pending = result;
          handler.postDelayed(timeout, 60000);
          if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {Manifest.permission.RECORD_AUDIO}, AUDIO_PERMISSION);
          } else { startDictation(); }
          break;
        case "stop":
          if (recognizer != null && capturing) recognizer.stopListening();
          else finish(null, null);
          result.success(null);
          break;
        case "cancel":
          finish(null, null);
          result.success(null);
          break;
        default: result.notImplemented();
      }
    });
  }

  private void startDictation() {
    if (pending == null || Build.VERSION.SDK_INT < 31) return;
    try {
      recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this);
      capturing = false;
      final SpeechRecognizer active = recognizer;
      recognizer.setRecognitionListener(new RecognitionListener() {
        public void onReadyForSpeech(Bundle params) {}
        public void onBeginningOfSpeech() {}
        public void onRmsChanged(float rms) {}
        public void onBufferReceived(byte[] buffer) {}
        public void onEndOfSpeech() {}
        public void onPartialResults(Bundle results) {}
        public void onEvent(int type, Bundle params) {}
        public void onError(int error) {
          if (recognizer == active) {
            android.util.Log.i("TransitoDictation", "Recognition error " + error);
            finish(null, "recognition_" + error);
          }
        }
        public void onResults(Bundle results) {
          if (recognizer != active) return;
          ArrayList<String> texts = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
          finish(texts == null || texts.isEmpty() ? null : texts.get(0), null);
        }
      });
      Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
      intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
      intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-ES");
      intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false);
      if (Build.VERSION.SDK_INT >= 33) {
        active.checkRecognitionSupport(intent, getMainExecutor(), new RecognitionSupportCallback() {
          public void onSupportResult(RecognitionSupport support) {
            if (pending == null || recognizer != active || capturing) return;
            String language = spanishLanguage(support.getInstalledOnDeviceLanguages());
            if (language == null) { finish(null, "language_missing"); return; }
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, language);
            android.util.Log.i("TransitoDictation", "On-device language " + language);
            listenLocally(active, intent);
          }
          public void onError(int error) {
            if (pending != null && recognizer == active) {
              // Algunos motores no implementan la consulta. Seguir siempre local.
              listenLocally(active, intent);
            }
          }
        });
      } else {
        listenLocally(active, intent);
      }
    } catch (Exception error) { finish(null, "unavailable"); }
  }

  private void listenLocally(SpeechRecognizer active, Intent intent) {
    if (pending == null || recognizer != active || capturing) return;
    capturing = true;
    try { active.startListening(intent); }
    catch (Exception error) { finish(null, "unavailable"); }
  }

  private String spanishLanguage(List<String> installed) {
    for (String preferred : new String[] {Locale.getDefault().toLanguageTag(), "es-ES", "es-US"}) {
      for (String language : installed) {
        if (language.toLowerCase(Locale.ROOT).startsWith("es") && language.equalsIgnoreCase(preferred)) return language;
      }
    }
    for (String language : installed) {
      if (language.equalsIgnoreCase("es") || language.toLowerCase(Locale.ROOT).startsWith("es-")) return language;
    }
    return null;
  }

  private void finish(String text, String error) {
    MethodChannel.Result result = pending;
    pending = null;
    capturing = false;
    handler.removeCallbacks(timeout);
    if (recognizer != null) {
      SpeechRecognizer previous = recognizer;
      recognizer = null;
      previous.cancel();
      previous.destroy();
    }
    if (result != null) {
      if (error == null) result.success(text);
      else result.error(error, "No se pudo completar el dictado local", null);
    }
  }

  @Override
  public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grants) {
    super.onRequestPermissionsResult(requestCode, permissions, grants);
    if (requestCode == AUDIO_PERMISSION && pending != null) {
      if (grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED) startDictation();
      else finish(null, "permission");
    }
  }

  @Override
  protected void onStop() {
    finish(null, null);
    super.onStop();
  }

  @Override
  protected void onDestroy() {
    finish(null, null);
    super.onDestroy();
  }
}
