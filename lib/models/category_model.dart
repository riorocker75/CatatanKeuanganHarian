import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final IconData? icon;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.icon,
    required this.createdAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? '';
    final codePoint = data['icon'] as int?;

    return CategoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: name,
      type: data['type'] ?? 'expense',
      icon: AppConstants.getIconByCodePoint(codePoint, fallbackCategory: name),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'icon': icon?.codePoint,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}