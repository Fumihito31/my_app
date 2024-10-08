// lib/services/matching_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MatchingService {
  Future<void> saveHeartedUser(String heartedUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('hearts').add({
        'heartedBy': user.uid,
        'heartedUser': heartedUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Increment the number of hearts for the hearted user
      final userDoc = FirebaseFirestore.instance.collection('users').doc(heartedUserId);
      await userDoc.update({
        'heartsCount': FieldValue.increment(1),
      });
    }
  }

  Future<void> deleteHeartedUser(String heartedUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('hearts')
          .where('heartedBy', isEqualTo: user.uid)
          .where('heartedUser', isEqualTo: heartedUserId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Decrement the number of hearts for the hearted user
      final userDoc = FirebaseFirestore.instance.collection('users').doc(heartedUserId);
      await userDoc.update({
        'heartsCount': FieldValue.increment(-1),
      });
    }
  }

  Future<bool> isUserHearted(String heartedUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('hearts')
          .where('heartedBy', isEqualTo: user.uid)
          .where('heartedUser', isEqualTo: heartedUserId)
          .get();
      return snapshot.docs.isNotEmpty;
    }
    return false;
  }

  int _calculateMatchScore(List<dynamic> userInterests, List<dynamic> profileInterests, int heartsCount) {
    int score = 0;
    for (var interest in userInterests) {
      if (profileInterests.contains(interest)) {
        score++;
      }
    }
    // Include hearts count in the match score
    score += heartsCount;
    return score;
  }

  Future<List<Map<String, dynamic>>> fetchProfiles(int pageSize, DocumentSnapshot? lastDocument) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userInterests = userDoc.data()?['interests'] ?? [];
      final currentUserUid = user.uid;

      QuerySnapshot snapshot;
      if (lastDocument == null) {
        snapshot = await FirebaseFirestore.instance.collection('users').limit(pageSize).get();
      } else {
        snapshot = await FirebaseFirestore.instance.collection('users').startAfterDocument(lastDocument).limit(pageSize).get();
      }

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;
      }

      final List<Map<String, dynamic>> fetchedProfiles = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final age = data['birthday'] != null ? _calculateAge(data['birthday']).toString() : 'Unknown';
        final matchScore = _calculateMatchScore(userInterests, data['interests'] ?? [], data['heartsCount'] ?? 0);
        return {
          'name': data['username'] ?? 'Unknown',
          'age': age ?? 'Unknown',
          'image': data['imageUrl'] ?? 'https://via.placeholder.com/150',
          'interests': data['interests'] ?? [],
          'about': data['about'] ?? 'No information',
          'uid': doc.id,
          'matchScore': matchScore,
        };
      }).where((profile) => profile['uid'] != currentUserUid).toList();

      fetchedProfiles.sort((a, b) => b['matchScore'].compareTo(a['matchScore']));

      return fetchedProfiles;
    }
    return [];
  }



  Future<void> saveStarredUser(String starredUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('stars').add({
        'starredBy': user.uid,
        'starredUser': starredUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> addUserToMatches(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final matchesJson = prefs.getStringList('cachedMatches') ?? [];
    matchesJson.add(jsonEncode(user));
    await prefs.setStringList('cachedMatches', matchesJson);
  }

  Future<Map<String, dynamic>> fetchUserById(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = userDoc.data();
    return {
      'name': data?['username'] ?? 'Unknown',
      'age': data?['birthday'] != null ? _calculateAge(data!['birthday']).toString() : 'Unknown',
      'image': data?['imageUrl'] ?? 'https://via.placeholder.com/150',
      'uid': userDoc.id,
    };
  }

  Future<void> removeUserFromMatches(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final matchesJson = prefs.getStringList('cachedMatches') ?? [];
    matchesJson.removeWhere((match) {
      final matchMap = jsonDecode(match) as Map<String, dynamic>;
      return matchMap['uid'] == userId;
    });
    await prefs.setStringList('cachedMatches', matchesJson);
  }

  Future<void> deleteStarredUser(String starredUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('stars')
          .where('starredBy', isEqualTo: user.uid)
          .where('starredUser', isEqualTo: starredUserId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchStarredUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('stars')
          .where('starredBy', isEqualTo: user.uid)
          .get();

      final List<String> starredUserIds = snapshot.docs.map((doc) => doc['starredUser'] as String).toList();

      if (starredUserIds.isEmpty) {
        return [];
      }

      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: starredUserIds)
          .get();

      return userDocs.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['username'] ?? 'Unknown',
          'age': data['birthday'] != null ? _calculateAge(data['birthday']).toString() : 'Unknown',
          'image': data['imageUrl'] ?? 'https://via.placeholder.com/150',
          'uid': doc.id,
        };
      }).toList();
    }
    return [];
  }

  Future<void> cacheMatches(List<Map<String, dynamic>> matches) async {
    final prefs = await SharedPreferences.getInstance();
    final matchesJson = matches.map((match) => jsonEncode(match)).toList(); // Convert each match to a JSON string
    await prefs.setStringList('cachedMatches', matchesJson);
  }
  Future<List<Map<String, dynamic>>> getCachedMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final matchesJson = prefs.getStringList('cachedMatches') ?? [];
    return matchesJson.map((match) => jsonDecode(match) as Map<String, dynamic>).toList(); // Decode each JSON string back to a Map
  }

  int _calculateAge(String birthday) {
    DateTime birthDate = DateTime.parse(birthday);
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<bool> isUserStarred(String starredUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('stars')
          .where('starredBy', isEqualTo: user.uid)
          .where('starredUser', isEqualTo: starredUserId)
          .get();
      return snapshot.docs.isNotEmpty;
    }
    return false;
  }

  Future<void> saveLastViewedProfileIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastViewedProfileIndex', index);
  }

  Future<int> getLastViewedProfileIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lastViewedProfileIndex') ?? 0;
  }

  Future<bool> isUserLiked(String likedUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('likedBy', isEqualTo: user.uid)
          .where('likedUser', isEqualTo: likedUserId)
          .get();
      return snapshot.docs.isNotEmpty;
    }
    return false;
  }

  Future<void> deleteLikedUser(String likedUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('likedBy', isEqualTo: user.uid)
          .where('likedUser', isEqualTo: likedUserId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Decrement the number of likes for the liked user
      final userDoc = FirebaseFirestore.instance.collection('users').doc(likedUserId);
      await userDoc.update({
        'likesCount': FieldValue.increment(-1),
      });
    }
  }
}