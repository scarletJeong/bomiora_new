class CompanyInfo {
  final String companyName;
  final String ownerName;
  final String businessNumber;
  final String mailOrderNumber;
  final String phone;
  final String fax;
  final String email;
  final String address;

  const CompanyInfo({
    required this.companyName,
    required this.ownerName,
    required this.businessNumber,
    required this.mailOrderNumber,
    required this.phone,
    required this.fax,
    required this.email,
    required this.address,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    return CompanyInfo(
      companyName: read('companyName'),
      ownerName: read('ownerName'),
      businessNumber: read('businessNumber'),
      mailOrderNumber: read('mailOrderNumber'),
      phone: read('phone'),
      fax: read('fax'),
      email: read('email'),
      address: read('address'),
    );
  }
}
