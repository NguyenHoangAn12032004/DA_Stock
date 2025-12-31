class CompanyOverview {
  final String symbol;
  final String exchange;
  final String industry;
  final String companyName;
  final String establishedYear;
  final String noEmployees;

  CompanyOverview({
    required this.symbol,
    required this.exchange,
    required this.industry,
    required this.companyName,
    required this.establishedYear,
    required this.noEmployees,
  });

  factory CompanyOverview.fromJson(Map<String, dynamic> json) {
    return CompanyOverview(
      symbol: json['ticker'] ?? '',
      exchange: json['exchange'] ?? '',
      industry: json['industry'] ?? '',
      companyName: json['companyName'] ?? '',
      establishedYear: json['establishedYear'] ?? '',
      noEmployees: json['noEmployees']?.toString() ?? '',
    );
  }
}
