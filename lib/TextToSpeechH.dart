import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:text_to_speech/text_to_speech.dart';

class Tts extends StatefulWidget {
  const Tts({Key? key}) : super(key: key);

  @override
  State<Tts> createState() => _TtsState();
}

class _TtsState extends State<Tts> {
  final String defaultLanguage = 'en-US';

  TextToSpeech tts = TextToSpeech();
  stt.SpeechToText speech = stt.SpeechToText();

  Color bgColor = const Color(0xff324376);

  Timer? _commandModeTimer;
  Timer? _resetTextTimer;
  bool isListening = false;
  bool _isCommandMode = false;

  String text = '';
  double volume = 1; // Range: 0-1
  double rate = 1.0; // Range: 0-2
  double pitch = 1.0; // Range: 0-2

  String? language;
  String? languageCode;
  List<String> languages = <String>[];
  List<String> languageCodes = <String>[];
  String? voice;

  TextEditingController textEditingController = TextEditingController();

  bool get supportPause => defaultTargetPlatform != TargetPlatform.android;

  bool get supportResume => defaultTargetPlatform != TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    textEditingController.text = text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initLanguages();
    });
    initializeSpeechRecognition();
  }

  Future<void> initLanguages() async {
    languageCodes = await tts.getLanguages();
    final List<String>? displayLanguages = await tts.getDisplayLanguages();
    if (displayLanguages == null) {
      return;
    }

    languages.clear();
    for (final dynamic lang in displayLanguages) {
      languages.add(lang as String);
    }

    final String? defaultLangCode = await tts.getDefaultLanguage();
    if (defaultLangCode != null && languageCodes.contains(defaultLangCode)) {
      languageCode = defaultLangCode;
    } else {
      languageCode = defaultLanguage;
    }
    language = await tts.getDisplayLanguageByCode(languageCode!);
    voice = await getVoiceByLang(languageCode!);

    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> getVoiceByLang(String lang) async {
    final List<String>? voices = await tts.getVoiceByLang(languageCode!);
    if (voices != null && voices.isNotEmpty) {
      return voices.first;
    }
    return null;
  }

  void initializeSpeechRecognition() async {
    await speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    startListeningForCommands();
  }

  void startListeningForCommands() async {
    speech.listen(
      onResult: (val) {
        String recognizedText = val.recognizedWords.toLowerCase();
        print('Recognized Text: $recognizedText');
        if (!_isCommandMode && recognizedText.contains('hello brother')) {
          setState(() {
            _isCommandMode = true;
            text = ''; // Clear any previous recognized text
          });
          startListeningForActions();
        }
      },
      localeId: 'en-US',
    );
  }

  void startListeningForActions() async {
    speech.listen(
      onResult: (val) {
        String recognizedText = val.recognizedWords.toLowerCase();
        print('Command: $recognizedText');
        if (recognizedText.contains('speak')) {
          speak();
        } else if (recognizedText.contains('stop')) {
          tts.stop();
        } else if (recognizedText.contains('pause')) {
          if (supportPause) tts.pause();
        } else if (recognizedText.contains('resume')) {
          if (supportResume) tts.resume();
        }

        // Reset command mode timer
        _commandModeTimer?.cancel();
        _commandModeTimer = Timer(Duration(seconds: 2), () {
          setState(() {
            _isCommandMode = false;
          });
          startListeningForCommands();
        });
      },
      localeId: 'id-ID',
    );
  }

  void startListening() async {
    try {
      bool available = await speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() {
          isListening = true;
          text = '';
        });
        speech.listen(
          onResult: (val) => setState(() {
            text = val.recognizedWords;
            textEditingController.text = text;
          }),
          localeId: languageCode,
        );
      } else {
        setState(() {
          isListening = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech recognition not available.')),
          );
        });
      }
    } catch (e) {
      print('Error initializing speech recognition: $e');
      setState(() {
        isListening = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing speech recognition: $e')),
        );
      });
    }
  }

  void stopListening() {
    speech.stop();
    setState(() {
      isListening = false;
    });
  }

  void speak() {
    tts.setVolume(volume);
    tts.setRate(rate);
    if (languageCode != null) {
      tts.setLanguage(languageCode!);
    }
    tts.setPitch(pitch);
    tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Text-to-Speech & Speech-to-Text',
              style: TextStyle(color: Colors.white)),
          backgroundColor: bgColor,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: textEditingController,
                    maxLines: 5,
                    cursorColor: bgColor,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: bgColor),
                      ),
                    ),
                    onChanged: (String newText) {
                      setState(() {
                        text = newText;
                      });
                    },
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Volume'),
                      Expanded(
                        child: Slider(
                          value: volume,
                          min: 0,
                          max: 1,
                          activeColor: bgColor,
                          inactiveColor: bgColor.withOpacity(0.3),
                          label: volume.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              volume = value;
                            });
                          },
                        ),
                      ),
                      Text('(${volume.toStringAsFixed(2)})'),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Rate'),
                      Expanded(
                        child: Slider(
                          value: rate,
                          min: 0,
                          max: 2,
                          activeColor: bgColor,
                          inactiveColor: bgColor.withOpacity(0.3),
                          label: rate.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              rate = value;
                            });
                          },
                        ),
                      ),
                      Text('(${rate.toStringAsFixed(2)})'),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Pitch'),
                      Expanded(
                        child: Slider(
                          value: pitch,
                          min: 0,
                          max: 2,
                          activeColor: bgColor,
                          inactiveColor: bgColor.withOpacity(0.3),
                          label: pitch.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              pitch = value;
                            });
                          },
                        ),
                      ),
                      Text('(${pitch.toStringAsFixed(2)})'),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Language'),
                      const SizedBox(
                        width: 20,
                      ),
                      DropdownButton<String>(
                        value: language,
                        icon: Icon(
                          Icons.arrow_downward,
                          color: bgColor,
                        ),
                        iconSize: 24,
                        elevation: 16,
                        style: TextStyle(color: bgColor),
                        underline: Container(
                          height: 2,
                          color: bgColor,
                        ),
                        onChanged: (String? newValue) async {
                          languageCode =
                              await tts.getLanguageCodeByName(newValue!);
                          voice = await getVoiceByLang(languageCode!);
                          setState(() {
                            language = newValue;
                          });
                        },
                        items: languages
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Voice'),
                      const SizedBox(
                        width: 20,
                      ),
                      Text(voice ?? '-'),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(right: 10),
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.all<Color>(bgColor),
                            ),
                            child: const Text('Stop Speaking',
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              tts.stop();
                            },
                          ),
                        ),
                      ),
                      if (supportPause)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(right: 10),
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(bgColor),
                              ),
                              child: const Text('Pause',
                                  style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                tts.pause();
                              },
                            ),
                          ),
                        ),
                      if (supportResume)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(right: 10),
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(bgColor),
                              ),
                              child: const Text('Resume',
                                  style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                tts.resume();
                              },
                            ),
                          ),
                        ),
                      Expanded(
                          child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all<Color>(bgColor),
                        ),
                        child: const Text('Speak',
                            style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          speak();
                        },
                      ))
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                                isListening ? Colors.red : bgColor),
                          ),
                          child: Text(
                              isListening ? 'Listening...' : 'Speech To Text',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            if (!isListening) {
                              startListening();
                            } else {
                              stopListening();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                                isListening ? Colors.red : bgColor),
                          ),
                          child: Text(
                              isListening
                                  ? 'Listening...'
                                  : 'Command with Voice',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            if (!isListening) {
                              setState(() {
                                _isCommandMode = true;
                              });
                              startListeningForCommands();
                            } else {
                              stopListening();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _isCommandMode
                          ? Icon(Icons.mic, color: Colors.red, size: 40)
                          : Icon(Icons.mic_none, color: Colors.grey, size: 40),
                      const SizedBox(width: 10),
                      Text(
                        _isCommandMode
                            ? 'Command Mode Active'
                            : 'Say "Halo BisikinDigital" to start',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
