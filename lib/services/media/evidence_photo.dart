enum EvidencePhotoCategory {
  panoramica('PANORAMICA', 'Panorámica'),
  licencia('LICENCIA', 'Licencia'),
  placa('PLACA', 'Placa'),
  otra('OTRA', 'Otra');

  const EvidencePhotoCategory(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static EvidencePhotoCategory fromDatabase(String value) {
    return EvidencePhotoCategory.values.firstWhere(
      (category) => category.databaseValue == value,
      orElse: () => EvidencePhotoCategory.otra,
    );
  }
}
