import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';


class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'categories';

  Future<void> addCategory(CategoryModel category) async {
    await _firestore.collection(_collection).add(category.toFirestore());
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection(_collection)
        .doc(category.id)
        .update(category.toFirestore());
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<CategoryModel>> getUserCategories(String userId, String type) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  Future<List<String>> getAllCategories(String userId, String type) async {
    final defaults = type == 'income'
        ? ['Ngojol']
        : ['Makanan'];

    final custom = await getUserCategories(userId, type).first;
    final customNames = custom.map((c) => c.name).toList();

    return [...defaults, ...customNames];
  }
}