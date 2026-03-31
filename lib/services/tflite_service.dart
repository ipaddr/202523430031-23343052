import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionResult {
  const DetectionResult({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<int> _inputShape = const [1, 224, 224, 3];
  List<int> _outputShape = const [1, 1];

  Future<void> loadModel({
    required String modelPath,
    required String labelsPath,
  }) async {
    _interpreter = await Interpreter.fromAsset(modelPath);
    _labels = await _loadLabels(labelsPath);

    _inputShape = _interpreter!.getInputTensor(0).shape;
    _outputShape = _interpreter!.getOutputTensor(0).shape;
  }

  Future<DetectionResult> detectImage(String imagePath) async {
    if (_interpreter == null) {
      throw Exception('Interpreter belum dimuat.');
    }

    final imageBytes = await File(imagePath).readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw Exception('Gambar tidak dapat dibaca.');
    }

    final inputHeight = _inputShape[1];
    final inputWidth = _inputShape[2];

    final resizedImage = img.copyResize(
      decodedImage,
      width: inputWidth,
      height: inputHeight,
    );

    final input = List.generate(1, (_) {
      return List.generate(inputHeight, (y) {
        return List.generate(inputWidth, (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        });
      });
    });

    final outputClasses = _outputShape.last;
    final output = [List<double>.filled(outputClasses, 0.0)];

    _interpreter!.run(input, output);

    final probabilities = output.first;
    final topIndex = _argMax(probabilities);
    final topConfidence = probabilities[topIndex];

    final label = (topIndex < _labels.length)
        ? _labels[topIndex]
        : 'Kelas ke-${topIndex + 1}';

    return DetectionResult(
      label: _cleanLabel(label),
      confidence: topConfidence,
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  Future<List<String>> _loadLabels(String labelsPath) async {
    final raw = await rootBundle.loadString(labelsPath);
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  int _argMax(List<double> values) {
    var maxIndex = 0;
    var maxValue = values[0];

    for (var i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }

    return maxIndex;
  }

  String _cleanLabel(String rawLabel) {
    final parts = rawLabel.split(' ');
    if (parts.isNotEmpty && int.tryParse(parts.first) != null) {
      return parts.skip(1).join(' ').trim();
    }
    return rawLabel;
  }
}
