import 'dart:html' as html;
import 'package:flutter/material.dart';

class WebSmartHomeScreenImpl extends StatefulWidget {
  const WebSmartHomeScreenImpl({super.key});

  @override
  State<WebSmartHomeScreenImpl> createState() => _WebSmartHomeScreenImplState();
}

class _WebSmartHomeScreenImplState extends State<WebSmartHomeScreenImpl> {
  @override
  void initState() {
    super.initState();
    final pathname = html.window.location.pathname ?? '';
    if (!pathname.endsWith('/smart-home.html') && pathname != '/smart-home.html') {
      html.window.location.replace('smart-home.html');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}