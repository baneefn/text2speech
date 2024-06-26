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
  final String defaultLanguage = 'in-ID';
  final TextToSpeech tts = TextToSpeech();
  final stt.SpeechToText speech = stt.SpeechToText();
  final Color bgColor = const Color(0xff324376);

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

  final TextEditingController textEditingController = TextEditingController();
  final List<String> logMessages = [];
  final Set<String> uniqueCommands = {};

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
    try {
      languageCodes = await tts.getLanguages();
      final List<String>? displayLanguages = await tts.getDisplayLanguages();
      if (displayLanguages != null) {
        languages = displayLanguages;
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
    } catch (e) {
      addLog('Error initializing languages: $e');
    }
  }

  Future<String?> getVoiceByLang(String lang) async {
    try {
      final List<String>? voices = await tts.getVoiceByLang(lang);
      if (voices != null && voices.isNotEmpty) {
        return voices.first;
      }
    } catch (e) {
      addLog('Error getting voice by language: $e');
    }
    return null;
  }

  void initializeSpeechRecognition() async {
    try {
      await speech.initialize(
        onStatus: (val) => addLog('onStatus: $val'),
        onError: (val) => addLog('onError: $val'),
      );
    } catch (e) {
      addLog('Error initializing speech recognition: $e');
    }
  }

  void startListeningForCommands() async {
    setState(() {
      _isCommandMode = true;
    });
    speech.listen(
      onResult: (val) {
        String recognizedText = val.recognizedWords.toLowerCase();
        addLog('Command: $recognizedText');
        handleVoiceCommand(recognizedText);
      },
      localeId: 'in-ID',
    );
  }

  void handleVoiceCommand(String recognizedText) async {
    addLog('Recognized text: $recognizedText');

    if (!uniqueCommands.contains(recognizedText)) {
      uniqueCommands.add(recognizedText);

      // Normalize recognized text
      recognizedText = recognizedText.toLowerCase();

      if (recognizedText.contains('bicara')) {
        addLog('Executing: speak()');
        setState(() {
          if (textEditingController.text.isNotEmpty) {
            speak();
          } else {
            addLog('No text to speak');
          }
        });
      } else if (recognizedText.contains('berhenti')) {
        addLog('Executing: tts.stop()');
        tts.stop();
      } else if (recognizedText.contains('jeda')) {
        if (supportPause) {
          addLog('Executing: tts.pause()');
          tts.pause();
        }
      } else if (recognizedText.contains('lanjutkan')) {
        if (supportResume) {
          addLog('Executing: tts.resume()');
          tts.resume();
        }
      } else if (recognizedText.contains('reset volume')) {
        double newVolume = extractValue(recognizedText);
        if (newVolume >= 0 && newVolume <= 1) {
          setState(() {
            volume = newVolume;
          });
          addLog('Volume set to $volume');
        } else {
          addLog('Invalid volume value');
        }
      } else if (recognizedText.contains('reset pic')) {
        double newPitch = extractValue(recognizedText);
        if (newPitch >= 0 && newPitch <= 2) {
          setState(() {
            pitch = newPitch;
          });
          addLog('Pitch set to $pitch');
        } else {
          addLog('Invalid pitch value');
        }
      } else if (recognizedText.contains('reset red')) {
        // corrected the command from "reset red" to "reset rate"
        double newRate = extractValue(recognizedText);
        if (newRate >= 0 && newRate <= 2) {
          setState(() {
            rate = newRate;
          });
          addLog('Rate set to $rate');
        } else {
          addLog('Invalid rate value');
        }
      }

      // Reset text after command
      _resetTextTimer?.cancel();
      _resetTextTimer = Timer(Duration(seconds: 2), () {
        setState(() {
          textEditingController.text =
              text; // Update text field with current text
        });
      });
    } else {
      addLog('Command already executed: $recognizedText');
    }
  }

  double extractValue(String text) {
    // Extract numerical value from text
    RegExp regExp = RegExp(r"[-+]?[0-9]*\.?[0-9]+");
    String? match = regExp.stringMatch(text);
    if (match != null) {
      return double.parse(match);
    } else {
      return 1.0;
    }
  }

  void stopListeningForCommands() {
    speech.stop();
    setState(() {
      _isCommandMode = false;
    });
  }

  void startListening() async {
    try {
      bool available = await speech.initialize(
        onStatus: (val) => addLog('onStatus: $val'),
        onError: (val) => addLog('onError: $val'),
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
      addLog('Error initializing speech recognition: $e');
      setState(() {
        isListening = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing speech recognition.')),
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

    addLog('Volume: $volume');
    addLog('Rate: $rate');
    addLog('Pitch: $pitch');
    addLog('Language: $languageCode');
    addLog('Text to speak: $text');

    if (text.isNotEmpty) {
      tts.speak(text);
    } else {
      addLog('No text to speak');
    }
  }

  void addLog(String message) {
    setState(() {
      if (logMessages.isEmpty || logMessages.last != message) {
        if (logMessages.length >= 5) {
          logMessages.removeAt(0);
        }
        logMessages.add(message);
      }
    });
    if (kDebugMode) {
      print(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
              'Text-to-Speech, Speech-to-Text & Speech Recognition',
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
                      border: const OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: bgColor),
                      ),
                      labelText: 'Enter Text',
                      labelStyle: TextStyle(color: bgColor),
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
                        icon: const Icon(Icons.arrow_downward),
                        iconSize: 24,
                        elevation: 16,
                        style: const TextStyle(color: Color(0xff324376)),
                        underline: Container(
                          height: 2,
                          color: const Color(0xff324376),
                        ),
                        onChanged: (String? newValue) async {
                          languageCode =
                              languageCodes[languages.indexOf(newValue!)];
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
                                  WidgetStateProperty.all<Color>(bgColor),
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
                                    WidgetStateProperty.all<Color>(bgColor),
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
                                    WidgetStateProperty.all<Color>(bgColor),
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
                              WidgetStateProperty.all<Color>(bgColor),
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
                            backgroundColor: WidgetStateProperty.all<Color>(
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
                            backgroundColor: WidgetStateProperty.all<Color>(
                                _isCommandMode ? Colors.red : bgColor),
                          ),
                          child: Text(
                              _isCommandMode
                                  ? 'Stop Command Mode'
                                  : 'Command with Voice',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            if (!_isCommandMode) {
                              startListeningForCommands();
                            } else {
                              stopListeningForCommands();
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
                            ? 'Command Mode Active: Use phrases like "bicara", "berhenti", "jeda", "lanjutkan", "riset volume", "riset pic", "reset red"'
                            : 'Say a command to control TTS',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: bgColor),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Log Messages',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        for (var message in logMessages)
                          Text(
                            message,
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
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
