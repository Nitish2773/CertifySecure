// lib/models/certificate_model.dart

class Certificate {
  final String studentId;
  final String certificateId;
  final String hash;
  final String transactionHash;

  Certificate({
    required this.studentId,
    required this.certificateId,
    required this.hash,
    required this.transactionHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'certificateId': certificateId,
      'hash': hash,
      'transactionHash': transactionHash,
    };
  }

  factory Certificate.fromMap(Map<String, dynamic> map) {
    return Certificate(
      studentId: map['studentId'],
      certificateId: map['certificateId'],
      hash: map['hash'],
      transactionHash: map['transactionHash'],
    );
  }
}