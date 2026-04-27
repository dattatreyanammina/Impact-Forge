import 'package:image_picker/image_picker.dart';

class PickedImage {
  final XFile file;
  final List<int> bytes;

  const PickedImage({
    required this.file,
    required this.bytes,
  });
}
