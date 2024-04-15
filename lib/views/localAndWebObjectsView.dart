import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image/image.dart' as img;

import 'package:vector_math/vector_math_64.dart';

class LocalAndWebObjectsView extends StatefulWidget {
  const LocalAndWebObjectsView({Key? key}) : super(key: key);

  @override
  State<LocalAndWebObjectsView> createState() => _LocalAndWebObjectsViewState();
}

class _LocalAndWebObjectsViewState extends State<LocalAndWebObjectsView> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  ScreenshotController screenshotController = ScreenshotController();
  //String localObjectReference;
  ARNode? localObjectNode;

  //String webObjectReference;
  ARNode? webObjectNode;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
    ),
  );

  bool _canProcess = true;
  bool _isBusy = false;
  int frameCounter = 0;

  Timer? screenshotTimer;

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    arSessionManager.dispose();
    screenshotTimer?.cancel();
    super.dispose();
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess || _isBusy) {
      return;
    }

    _isBusy = true;

    try {
      print("Before of faces detected:");

      // Process the input image to detect faces
      final faces = await _faceDetector.processImage(inputImage);

      // Log the number of faces detected
      print("After of faces detected: ${faces.length}");

      // Iterate through the list of detected faces
      for (Face face in faces) {
        // Get the bounding box of the current face
        Rect boundingBox = face.boundingBox;
        print("Bounding box of face: $boundingBox");

        // Calculate the center of the face's bounding box
        double centerX = boundingBox.left + boundingBox.width / 2;
        double centerY = boundingBox.top + boundingBox.height / 2;

        // Convert the center point to AR coordinates (z-value can be adjusted)
        Vector3 facePosition = Vector3(centerX, centerY, -5.0);

        // Create a new ARNode for each detected face
        ARNode arNode = ARNode(
          type: NodeType
              .localGLTF2, // Specify the type of AR node (e.g., local GLTF2 asset)
          uri: "assets/Chicken_01/Chicken_01.gltf", // URI of the AR asset
          scale: Vector3(0.2, 0.2, 0.2), // Adjust the scale as needed
          position:
              facePosition, // Position at the center of the detected face's bounding box
          rotation: Vector4(0.0, 0.0, 0.0,
              0.0), // Rotation of the AR asset (adjust as needed)
        );

        // Add the AR node to the AR session
        bool? didAddNode = await arObjectManager.addNode(arNode);
        print("AddedAR Node");
        if (didAddNode != null && didAddNode) {
          print("AR node added successfully for the face.");
        } else {
          print("Failed to add AR node for the face.");
        }
      }
    } catch (e) {
      print("Error during face detection: $e");
    }

    // Set _isBusy to false to allow further processing
    _isBusy = false;
  }

  Future<dynamic> ShowCapturedWidget(
      BuildContext context, Uint8List capturedImage) {
    return showDialog(
      useSafeArea: false,
      context: context,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text("Captured widget screenshot"),
        ),
        body: Center(
            child: capturedImage != null
                ? Image.memory(capturedImage)
                : Container()),
      ),
    );
  }

  _saved(image) async {
    final result = await ImageGallerySaver.saveImage(image);
    print("File Saved to Gallery");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Local / Web Objects"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * .8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Screenshot(
                  controller: screenshotController,
                  child: ARView(
                    onARViewCreated: onARViewCreated,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                      onPressed: onLocalObjectButtonPressed,
                      child: const Text("Add / Remove Local Object")),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: ElevatedButton(
                      onPressed: onWebObjectAtButtonPressed,
                      child: const Text("Add / Remove Web Object")),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    // Initialize AR session
    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
    );
    arObjectManager.onInitialize();

    // Set up screenshot timer to take a screenshot every 2 frames
    screenshotTimer = Timer.periodic(
      Duration(milliseconds: 500), // Adjust the interval as needed
      (timer) {
        frameCounter++;
        if (frameCounter % 2 == 0) {
          captureARView();
        }
      },
    );
  }

  Future<void> captureARView() async {
    final Uint8List? screenshot = await screenshotController.capture();

    if (screenshot != null) {
      // Convert the screenshot to InputImage
      final InputImage inputImage = convertScreenshotToInputImage(screenshot);
      print("Called");
      // Call the processImage function
      // _saved(screenshot);

      _processImage(inputImage);
    }
  }

  // Convert screenshot data to InputImage
  InputImage convertScreenshotToInputImage(Uint8List screenshot) {
    // Calculate the width and height of the image based on the context
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    // Assuming RGBA format (4 bytes per pixel)
    final int bytesPerPixel = 4;
    final int bytesPerRow = (width * bytesPerPixel).toInt();

    // Convert the screenshot data to InputImage format
    return InputImage.fromBytes(
      bytes: screenshot,
      metadata: InputImageMetadata(
        size: Size(width, height),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yv12, // Use the appropriate format
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  Future<void> onLocalObjectButtonPressed() async {
    Random random = Random();
    double randomNumber = random.nextInt(20).toDouble();
    var newNode = ARNode(
      type: NodeType.localGLTF2,
      uri: "assets/Chicken_01/Chicken_01.gltf",
      scale: Vector3(0.2, 0.2, 0.2),
      position: Vector3(randomNumber, 0.0, -5.0),
      rotation: Vector4(1.0, 0.0, 0.0, 0.0),
    );
    bool? didAddLocalNode = await arObjectManager.addNode(newNode);
    localObjectNode = (didAddLocalNode!) ? newNode : null;
  }

  Future<void> onWebObjectAtButtonPressed() async {
    if (webObjectNode != null) {
      arObjectManager.removeNode(webObjectNode!);
      webObjectNode = null;
    } else {
      var newNode = ARNode(
        type: NodeType.webGLB,
        uri:
            "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Fox/glTF-Binary/Fox.glb",
        scale: Vector3(0.2, 0.2, 0.2),
      );
      bool? didAddWebNode = await arObjectManager.addNode(newNode);
      webObjectNode = (didAddWebNode!) ? newNode : null;
    }
  }
}
