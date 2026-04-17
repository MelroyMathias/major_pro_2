import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

class VideoStreamView extends StatefulWidget {
  final String streamUrl;
  const VideoStreamView({super.key, required this.streamUrl});

  @override
  State<VideoStreamView> createState() => _VideoStreamViewState();
}

class _VideoStreamViewState extends State<VideoStreamView> {
  final String viewID = "videoElementWeb";

  @override
  void initState() {
    super.initState();
    final image = html.ImageElement()
      ..src = widget.streamUrl
      ..style.width = "100%"
      ..style.height = "100%"
      ..style.objectFit = "cover";

    ui.platformViewRegistry.registerViewFactory(
      viewID,
      (int viewId) => image,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewID);
  }
}
