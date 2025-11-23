class UserProfile {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? company; // Valgfri
  final String country;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.company,
    required this.country,
    required this.createdAt,
  });

  // Helper til at få fuldt navn
  String get fullName => "$firstName $lastName".trim();

  // Konverter til Map til Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'company': company,
      'country': country,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Opret fra Firestore data
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      company: map['company'],
      country: map['country'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}