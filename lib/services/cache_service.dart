import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CacheService {
  /// Clear cache — hanya bisa sebelum operasi Firestore
  static Future<void> clearAllOnLogout() async {
    try {
      // Terminate dulu, baru clear
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
      debugPrint('✅ Cache cleared & Firestore reinitialized');
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
      // Ignore error — tidak fatal
    }
  }
}