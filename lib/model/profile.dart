class Profile {
  String? username;
  String? email;
  String? password;

  Profile({this.email, this.password, this.username});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      username: json['username'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
    };
  }
}
