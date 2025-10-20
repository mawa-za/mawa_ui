import 'package:flutter/material.dart';

class BrandingService extends ChangeNotifier {
  String? logoUrl;

  void setLogo(String url) {
    logoUrl = url;
    notifyListeners();
  }
}

final brandingService = BrandingService();