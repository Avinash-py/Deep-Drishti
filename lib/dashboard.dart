import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import "package:flutter/material.dart";
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:vibration/vibration.dart';

late List<CameraDescription> _cameras;

class dashboard extends StatefulWidget {
  @override
  State<dashboard> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<dashboard> {
  late CameraController _controller;

  bool _isCameraInitialized = false;
  bool _isCameraOpen = false;
  int t = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.max);
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("Error: ${e.toString()}");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final FlutterTts tts = FlutterTts();
  File? _image;
  String? _response = "";
  final picker = ImagePicker();
  var height, width;
  bool showspiner = false;

  String ServerIP = "http://172.18.41.211:8000/imagespeak/predict";

  Future<XFile?> _takePicture() async {
    tts.stop();
    _isCameraOpen = true;
    try {
      CameraPreview(_controller);

      XFile file = await _controller.takePicture();

      setState(() {
        _isCameraOpen = false;
        if (file != null) {
          _image = File(file.path);
          print("image captured");
          sendImage();
        }
      });
    } on CameraException catch (e) {
      print("Error taking picture: ${e.toString()}");
      return null;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    tts.stop();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
    // if (pickedFile == null) {
    //   speak("No Image Found");
    // }
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        print("sending picked Image");
        sendImage();
      }
    });
  }

  Future<void> sendImage() async {
    setState(() {
      showspiner = true;
    });
    _response = "";
    if (_image == null) return;
    try {
      print(ServerIP);
      final uri = Uri.parse(ServerIP);
      final imageBytes = await _image!.readAsBytes();
      final request = http.MultipartRequest('POST', uri);

      final multiPartFile = http.MultipartFile.fromBytes(
        'ktp_image',
        imageBytes,
        filename: _image!.path.split('/').last,
      );

      request.files.add(multiPartFile);
      final response = await request.send();
      setState(() {
        showspiner = false;
      });
      // print(response.statusCode);
      if (response.statusCode == 200) {
        // showspiner = false;
        final responseData =
            jsonDecode(await response.stream.transform(utf8.decoder).join());

        speak(responseData["Result"]["results"]);
        print(responseData["Result"]["results"]);
        print(responseData);
        _response = responseData["Result"]["results"];
        setState(() {
          _response = responseData["Result"]["results"];
        });
      } else {
        setState(() {
          showspiner = false;
        });
        // showspiner = false;
        _response = "connection Error";
        speak(_response!);
        print('Error: ${response.statusCode}');
      }
    } on Exception catch (e) {
      setState(() {
        showspiner = false;
      });
      print('Error sending image: $e');
      speak("Check the Connection");
    }
  }

  Future<void> speak(String? text) async {
    print("speaking");
    print(ServerIP);
    tts.stop();
    text == "" ? text = "No Text to play." : text;
    await tts.setLanguage("hi-IN");
    // List<dynamic> languages = await tts.getVoices;
    // print(languages);

    await tts.setVoice({"name": "hi-in-x-hia-local", "locale": "hi-IN"});
    await tts.setPitch(1);
    await tts.speak(text!);
  }

  Future _displayBottomSheet() {
    return showModalBottomSheet(
      context: context!,
      backgroundColor: Colors.white,
      barrierColor: Colors.black87.withOpacity(0.5),
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        height: 300,
        width: width * .90,
        child: Column(children: [
          Text(
            "Select the Server",
            style: TextStyle(fontSize: 22),
          ),
          RadioListTile(
              title: Text("Server1"),
              autofocus: true,
              value: "http://172.18.41.211:8000/imagespeak/predict",
              groupValue: ServerIP,
              onChanged: (value) {
                setState(() {
                  ServerIP = value.toString();
                });
              }),
          RadioListTile(
              title: Text("Server2"),
              value: "http://10.8.1.100:5051/imagespeak/predict",
              groupValue: ServerIP,
              onChanged: (value) {
                setState(() {
                  ServerIP = value.toString();
                });
              }),
          RadioListTile(
              title: Text("Server3"),
              value: "http://172.18.40.248:5051/imagespeak/predict",
              groupValue: ServerIP,
              onChanged: (value) {
                setState(() {
                  ServerIP = value.toString();
                });
              }),
          Container(
            child: ListTile(
              title: TextField(
                // controller: _controler,
                decoration: InputDecoration(labelText: "custom IP"),
                onChanged: (value) {
                  setState(() {
                    ServerIP = value;
                  });
                },
              ),
            ),
          )
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("###############################");
    print(t);
    if (t == 0) {
      speak("Wellcome to DeepDrishti. Left swap to click the picture.");
      t = t + 1;
    }
    // speak(
    //     "Hi , Wellcome to the Deep Drishti , Please left swap to open camera ");
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    return ModalProgressHUD(
      inAsyncCall: showspiner,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 90,
          centerTitle: true,
          title: Image.asset(
            'assets/f_dd.png',
            // color: Colors.black,alignment: Alignment.center,
          ),
          // title: Text(
          //   "DeepDrishti",
          //   style: TextStyle(fontSize: 35),
          // ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          leading: Padding(
            padding: EdgeInsets.only(left: 15), // Adjust the value as needed
            child: Container(
              child: Image.asset(
                'assets/yamaha_logo.png',
              ),
            ),
          ),
          actions: [
            Container(
              padding: EdgeInsets.all(5),
              child: Image.asset(
                'assets/IIT_logo.png',
              ),
            ),
          ],
        ),
        body: Center(
          child: GestureDetector(
            onTap: () {
              speak("Left swap to click the picture.");
            },
            onHorizontalDragUpdate: (details) {
              // Swiping in right direction.
              if (details.delta.dx > 0) {
                print("Right");
                print(details.delta.dx);
              }

              // Swiping in left direction.
              if (details.delta.dx < 0) {
                _isCameraOpen = true;
                speak("Clicking. please wait.. ");
                Vibration.vibrate(duration: 250);

                _takePicture();

                // speak("Camera Opened , tab to click the pic.");
                // pickImage(ImageSource.camera);
              }
            },
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < 0) {
                print("upside");
                Vibration.vibrate(duration: 350);
                speak(_response); // Open camera logic
              }
              if (details.delta.dy > 0) {
                print("downside");
                Vibration.vibrate(duration: 2000, amplitude: 200);
                _displayBottomSheet();
              }
            },
            child: Center(
              child: Container(
                padding: EdgeInsets.only(bottom: 50),
                width: width * .98,
                height: height * .98,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: height * 0.6,
                      width: width * 1,
                      color: Colors.white,
                      child: Center(
                        child: (_image == null)
                            ? Image.asset(
                                'assets/dd.jpg',
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_image!.path),
                                // height: height * 0.9,
                                // width: width * 3,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    // SizedBox(height: 15),
                    Container(
                      alignment: Alignment.center,
                      width: width * .6,
                      height: height * 0.1,
                      color: Colors.white,
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        _response!.toUpperCase(),
                        // "In programming, a char refers to a data type used to store a single character. It's commonly utilized in languages like C, C++, and Java for tasks involving individual characters, such as string manipulation and character-based input/output operation.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: CurvedNavigationBar(
          backgroundColor: Colors.grey.shade800,
          color: Colors.grey.shade400,
          // animationCurve: Curves.elasticInOut,
          // animationDuration: Duration(microseconds: 100),
          items: [
            CurvedNavigationBarItem(
              child: Icon(Icons.browse_gallery_sharp),
              label: "Gallery",
              labelStyle: TextStyle(fontSize: 10),
            ),
            CurvedNavigationBarItem(
              child: Icon(Icons.play_circle),
              label: "Play",
              labelStyle: TextStyle(fontSize: 10),
            ),
            CurvedNavigationBarItem(
              child: Icon(Icons.camera),
              label: "Camera",
              labelStyle: TextStyle(fontSize: 10),
            ),
            CurvedNavigationBarItem(
              child: Icon(Icons.arrow_drop_down_circle_sharp),
              label: "Config",
              labelStyle: TextStyle(fontSize: 10),
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Vibration.vibrate(duration: 250, amplitude: 200);
                speak("Gallery");
                pickImage(ImageSource.gallery);
                break;
              case 1:
                speak("play");
                Vibration.vibrate(duration: 500, amplitude: 255);
                speak(_response == "" ? "Check the Connection." : _response!);
                print("Re-Play");

                break;
              case 2:
                Vibration.vibrate(
                    duration: 700, amplitude: 1, intensities: List.of([100]));
                speak("Clicking. please wait.");
                // pickImage(ImageSource.camera);
                _takePicture();
                break;
              case 3:
                _displayBottomSheet();
                print("sheet open ");
                break;
            }
          },
        ),
      ),
    );
  }
}
