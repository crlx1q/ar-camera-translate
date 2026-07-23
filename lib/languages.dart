import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// A user-facing language option for the translation target.
class AppLanguage {
  final String label;
  final TranslateLanguage lang;
  const AppLanguage(this.label, this.lang);
}

/// Top-10 target languages offered in the UI.
const List<AppLanguage> kLanguages = [
  AppLanguage('English', TranslateLanguage.english),
  AppLanguage('Русский', TranslateLanguage.russian),
  AppLanguage('Español', TranslateLanguage.spanish),
  AppLanguage('Français', TranslateLanguage.french),
  AppLanguage('Deutsch', TranslateLanguage.german),
  AppLanguage('Italiano', TranslateLanguage.italian),
  AppLanguage('Português', TranslateLanguage.portuguese),
  AppLanguage('中文', TranslateLanguage.chinese),
  AppLanguage('日本語', TranslateLanguage.japanese),
  AppLanguage('한국어', TranslateLanguage.korean),
];

/// Camera OCR script (ML Kit recognizes one script family at a time).
enum ScriptChoice { latin, chinese, japanese, korean, devanagari }

extension ScriptChoiceX on ScriptChoice {
  String get label {
    switch (this) {
      case ScriptChoice.latin:
        return 'ABC';
      case ScriptChoice.chinese:
        return '中文';
      case ScriptChoice.japanese:
        return '日本語';
      case ScriptChoice.korean:
        return '한국어';
      case ScriptChoice.devanagari:
        return 'देव';
    }
  }

  TextRecognitionScript get script {
    switch (this) {
      case ScriptChoice.latin:
        return TextRecognitionScript.latin;
      case ScriptChoice.chinese:
        return TextRecognitionScript.chinese;
      case ScriptChoice.japanese:
        return TextRecognitionScript.japanese;
      case ScriptChoice.korean:
        return TextRecognitionScript.korean;
      case ScriptChoice.devanagari:
        return TextRecognitionScript.devanagiri;
    }
  }
}
