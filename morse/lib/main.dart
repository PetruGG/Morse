import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MorseCodeApp());
}

class MorseCodeApp extends StatelessWidget {
  const MorseCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morse Code Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF009688),
          tertiary: const Color(0xFFFF9800),
        ),
        useMaterial3: true,
      ),
      home: const MorseCodeScreen(),
    );
  }
}

class MorseCodeScreen extends StatefulWidget {
  const MorseCodeScreen({super.key});

  @override
  _MorseCodeScreenState createState() => _MorseCodeScreenState();
}

class _MorseCodeScreenState extends State<MorseCodeScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _morseCode = '';
  bool _isFlashing = false;
  int _currentFlashIndex = -1;
  final Telephony telephony = Telephony.instance;
  List<SmsMessage> _messages = [];
  bool _hasSmsPermission = false;
  bool _hasTorchPermission = false;
  String _currentDecoding = '';
  String _decodedText = '';

  static const Map<String, String> _morseDictionary = {
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    'F': '..-.',
    'G': '--.',
    'H': '....',
    'I': '..',
    'J': '.---',
    'K': '-.-',
    'L': '.-..',
    'M': '--',
    'N': '-.',
    'O': '---',
    'P': '.--.',
    'Q': '--.-',
    'R': '.-.',
    'S': '...',
    'T': '-',
    'U': '..-',
    'V': '...-',
    'W': '.--',
    'X': '-..-',
    'Y': '-.--',
    'Z': '--..',
    '0': '-----',
    '1': '.----',
    '2': '..---',
    '3': '...--',
    '4': '....-',
    '5': '.....',
    '6': '-....',
    '7': '--...',
    '8': '---..',
    '9': '----.',
    '.': '.-.-.-',
    ',': '--..--',
    '?': '..--..',
    "'": '.----.',
    '!': '-.-.--',
    '/': '-..-.',
    '(': '-.--.',
    ')': '-.--.-',
    '&': '.-...',
    ':': '---...',
    ';': '-.-.-.',
    '=': '-...-',
    '+': '.-.-.',
    '-': '-....-',
    '_': '..--.-',
    '"': '.-..-.',
    '\$': '...-..-',
    '@': '.--.-.',
    ' ': '/',
  };

  static final Map<String, String> _reverseMorse = {
    for (var entry in _morseDictionary.entries) entry.value: entry.key,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final smsStatus = await Permission.sms.request();
    final cameraStatus = await Permission.camera.request();

    setState(() {
      _hasSmsPermission = smsStatus.isGranted;
      _hasTorchPermission = cameraStatus.isGranted;
    });

    if (_hasSmsPermission) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _messages.clear();
      });

      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final morseMessages =
          messages.where((msg) {
            final body = msg.body ?? '';
            if (!body.startsWith('MorseApp: ')) return false;

            final morseContent = body.substring('MorseApp: '.length);
            return RegExp(r'^[\.\-/ ]+$').hasMatch(morseContent);
          }).toList();
      setState(() {
        _messages = morseMessages;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
    }
  }

  String _encodeMorse(String text) {
    StringBuffer morse = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      String char = text[i].toUpperCase();
      if (_morseDictionary.containsKey(char)) {
        morse.write(_morseDictionary[char]);
        if (i < text.length - 1 && text[i + 1] != ' ') {
          morse.write(' ');
        }
      }
    }
    return morse.toString();
  }

  void _translateToMorse() {
    setState(() {
      _morseCode = _encodeMorse(_textController.text);
      _currentFlashIndex = -1;
      _currentDecoding = '';
      _decodedText = '';
    });
  }

  Future<void> _flashMorseCode([String? morseCode]) async {
    final codeToFlash = morseCode ?? _morseCode;
    if (codeToFlash.isEmpty || _isFlashing || !_hasTorchPermission) return;

    setState(() {
      _isFlashing = true;
      _currentFlashIndex = -1;
      _currentDecoding = '';
      _decodedText = '';
    });

    const dotDuration = Duration(milliseconds: 200);
    const dashDuration = Duration(milliseconds: 600);
    const symbolGap = Duration(milliseconds: 200);
    const letterGap = Duration(milliseconds: 600);

    try {
      for (int i = 0; i < codeToFlash.length; i++) {
        if (!_isFlashing) break;

        final char = codeToFlash[i];
        setState(() {
          _currentFlashIndex = i;
        });

        if (char == '.') {
          await TorchLight.enableTorch();
          await Future.delayed(dotDuration);
          await TorchLight.disableTorch();

          setState(() {
            _currentDecoding += '.';
          });
        } else if (char == '-') {
          await TorchLight.enableTorch();
          await Future.delayed(dashDuration);
          await TorchLight.disableTorch();

          setState(() {
            _currentDecoding += '-';
          });
        } else if (char == ' ') {
          await Future.delayed(symbolGap);

          if (_currentDecoding.isNotEmpty) {
            final decoded = _reverseMorse[_currentDecoding] ?? '';
            setState(() {
              _decodedText += decoded;
              _currentDecoding = '';
            });
          }
          continue;
        } else if (char == '/') {
          await Future.delayed(letterGap);
          setState(() {
            _decodedText += ' ';
          });
          continue;
        }

        if (i < codeToFlash.length - 1 &&
            codeToFlash[i + 1] != ' ' &&
            codeToFlash[i + 1] != '/') {
          await Future.delayed(symbolGap);
        }
      }

      if (_currentDecoding.isNotEmpty) {
        final decoded = _reverseMorse[_currentDecoding] ?? '';
        setState(() {
          _decodedText += decoded;
          _currentDecoding = '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flashlight error: $e')));
    } finally {
      setState(() {
        _isFlashing = false;
        _currentFlashIndex = -1;
      });
      await TorchLight.disableTorch();
    }
  }

  Future<void> _sendMorseSMS() async {
    if (_textController.text.isEmpty || _phoneController.text.isEmpty) return;

    if (!_hasSmsPermission) {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission required')),
        );
        return;
      }
      setState(() {
        _hasSmsPermission = true;
      });
    }

    final morse = _encodeMorse(_textController.text);
    final phoneNumber = _phoneController.text;
    final message = "MorseApp: $morse";

    try {
      await telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) {
          if (status == SendStatus.SENT) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SMS sent successfully')),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Failed to send SMS')));
          }
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send SMS: $e')));
    }
  }

  void _stopFlashing() {
    setState(() {
      _isFlashing = false;
      _currentFlashIndex = -1;
    });
    TorchLight.disableTorch();
  }

  @override
  void dispose() {
    _textController.dispose();
    _phoneController.dispose();
    TorchLight.disableTorch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Morse Code Translator'),
        backgroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh messages',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_hasTorchPermission)
                      Card(
                        color: Colors.amber[100],
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Camera permission required for flashlight',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        labelText: 'Enter text to translate',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.clear, color: colorScheme.primary),
                          onPressed: () {
                            _textController.clear();
                            setState(() {
                              _morseCode = '';
                              _currentDecoding = '';
                              _decodedText = '';
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _translateToMorse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.tertiary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Translate to Morse'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isFlashing
                                    ? _stopFlashing
                                    : () => _flashMorseCode(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isFlashing
                                      ? Colors.red
                                      : colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              _isFlashing ? 'Stop Flashing' : 'Flash Morse',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      color: colorScheme.secondary.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Morse Code:',
                              style: TextStyle(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: RichText(
                                text: TextSpan(
                                  children:
                                      _morseCode.split('').asMap().entries.map((
                                        entry,
                                      ) {
                                        final index = entry.key;
                                        final char = entry.value;
                                        final isActive =
                                            index == _currentFlashIndex;
                                        return TextSpan(
                                          text: char,
                                          style: TextStyle(
                                            fontSize: 24,
                                            color:
                                                isActive
                                                    ? Colors.red
                                                    : Colors.black,
                                            fontWeight:
                                                isActive
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                            if (_decodedText.isNotEmpty ||
                                _currentDecoding.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Decoded: $_decodedText${_currentDecoding.isNotEmpty ? ' (decoding: $_currentDecoding)' : ''}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Send Morse SMS:',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.phone,
                          color: colorScheme.primary,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _sendMorseSMS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.tertiary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Send Morse Code SMS'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Text(
                    'Received Morse Messages:',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        _messages.isEmpty
                            ? const Center(
                              child: Text('No Morse messages found'),
                            )
                            : ListView.builder(
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final morseCode =
                                    message.body?.replaceFirst(
                                      'MorseApp: ',
                                      '',
                                    ) ??
                                    '';

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'From: ${message.address ?? 'Unknown'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Morse: $morseCode',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: colorScheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _morseCode = morseCode;
                                                    _currentDecoding = '';
                                                    _decodedText = '';
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      colorScheme.secondary,
                                                ),
                                                child: const Text(
                                                  'Select',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed:
                                                    () => _flashMorseCode(
                                                      morseCode,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      colorScheme.primary,
                                                ),
                                                child: const Text(
                                                  'Flash',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
