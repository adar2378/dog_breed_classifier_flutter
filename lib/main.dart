import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flare_flutter/flare_actor.dart';

List<CameraDescription> cameras;

Future<void> main() async {
  cameras = await availableCameras();
  runApp(MaterialApp(home: CameraApp()));
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp>
    with SingleTickerProviderStateMixin {
  CameraController controller;
  int currentCamera = 0;
  bool isOffStaged = true;
  bool showpic = true;
  double _bottomPosition = 0;
  List<Widget> texts = List<Widget>();
  File _file;
  static final Animatable<Offset> _drawerDetailsTween = Tween<Offset>(
    begin: const Offset(0.0, 1.0),
    end: Offset.zero,
  ).chain(CurveTween(
    curve: Curves.fastOutSlowIn,
  ));
  Animation<Offset> _drawerDetailsPosition;
  AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _file = null;
    controller =
        CameraController(cameras[currentCamera], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _drawerDetailsPosition = _controller.drive(_drawerDetailsTween);
  }

  @override
  void dispose() {
    controller?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<File> _takePicture() async {
    if (!controller.value.isInitialized) {
      // TODO: show snackbar
      print("no camera selected! show snackbar");
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = "${extDir.path}/pictures/sandwhich";
    await Directory(dirPath).create(recursive: true);
    final String filePath = "$dirPath/${timestamp()}.jpg";

    if (controller.value.isTakingPicture) {
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      // TODO: show snackbar
      print("show snackbar here");
      return null;
    }
    setState(() {
      _file = File(filePath);
    });

    return File(filePath);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  upload(File imageFile) async {
    // open a bytestream
    var stream =
        new http.ByteStream(DelegatingStream.typed(imageFile.openRead()));
    // get file length
    var length = await imageFile.length();

    // string to uri
    //var uri = Uri.parse("http://10.0.2.2:5000/getresult");
    var uri = Uri.parse("https://f3e04dbd.ngrok.io/getresult");

    // create multipart request
    var request = new http.MultipartRequest("POST", uri);

    // multipart that takes file
    var multipartFile = new http.MultipartFile('file', stream, length,
        filename: basename(imageFile.path));

    // add file to multipart
    request.files.add(multipartFile);

    // send
    var response = await request.send();
    print(response.statusCode);

    // listen for response
    response.stream.transform(utf8.decoder).listen((value) {
      print(value);
      setState(() {
        //chips = getChips(value);
        texts = getTexts(value);
        isOffStaged = false;
        _controller.forward();
        print(isOffStaged);
      });
    });
  }

  List<Widget> getTexts(String value) {
    List<String> doggos = value.split(",");
    List<Widget> doggoChips = List<Widget>();
    doggoChips.add(Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: Icon(Icons.close),
        onPressed: () {
          setState(() {
            _controller.reverse();
            Future.delayed(Duration(milliseconds: 300)).then((v) {
              setState(() {
                isOffStaged = true;
                showpic = true;
                _bottomPosition = 0;
              });
            });
          });
        },
      ),
    ));
    for (int i = 0; i < doggos.length - 1; i++) {
      doggoChips.add(
        Padding(
          padding: i == 0
              ? EdgeInsets.only(bottom: 8.0)
              : EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            doggos[i].replaceRange(0, 1, doggos[i][0].toUpperCase()),
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
    }
    return doggoChips;
  }

  @override
  Widget build(BuildContext context) {
    // if (!controller.value.isInitialized) {
    //   return Container();
    // }
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Offstage(
                offstage: !showpic,
                child: controller.value.isInitialized
                    ? Transform.scale(
                        scale: controller.value.aspectRatio / deviceRatio,
                        child: Center(
                          child: AspectRatio(
                            child: CameraPreview(controller),
                            aspectRatio: controller.value.aspectRatio,
                          ),
                        ),
                      )
                    : Container()),
            AnimatedPositioned(
              bottom: _bottomPosition,
              duration: Duration(milliseconds: 300),
              left: 0,
              right: 0,
              curve: Curves.easeInOut,
              child: Container(
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(
                        Icons.photo,
                        color: Colors.white,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.camera,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _bottomPosition = -200;
                        });
                        _takePicture().then((imageFile) {
                          setState(() {
                            showpic = false;
                          });
                          upload(imageFile);
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.loop,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        currentCamera = (currentCamera + 1) % cameras.length;
                        controller = CameraController(
                            cameras[currentCamera], ResolutionPreset.high);
                        controller.initialize().then((_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {});
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Offstage(
                offstage: showpic,
                child: _file == null
                    ? Container()
                    : Stack(
                        children: <Widget>[
                          Image.file(
                            _file,
                            fit: BoxFit.fitHeight,
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                          ),
                          SizedBox.expand(
                            child: Container(
                              color: Colors.black45,
                              child: Center(
                                child: isOffStaged == true
                                    ? Container(
                                        height: 50,
                                        width: 50,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Container(),
                              ),
                            ),
                          ),
                        ],
                      )),
            Offstage(
              offstage: isOffStaged,
              child: SlideTransition(
                position: _drawerDetailsPosition,
                child: Card(
                  color: Colors.blue.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  margin: EdgeInsets.all(10),
                  child: Container(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: texts,
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
