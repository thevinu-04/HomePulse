class Floor {
  final String id;
  final String name;
  final String? imageAsset; // sample floor plan image, bundled in assets/floorplans/
  final int gridRows;
  final int gridCols;

  Floor({
    required this.id,
    required this.name,
    this.imageAsset,
    this.gridRows = 6,
    this.gridCols = 6,
  });

  factory Floor.fromMap(String id, Map<dynamic, dynamic> map) {
    return Floor(
      id: id,
      name: map['name'] ?? 'Untitled floor',
      imageAsset: map['imageAsset'],
      gridRows: map['gridRows'] ?? 6,
      gridCols: map['gridCols'] ?? 6,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (imageAsset != null) 'imageAsset': imageAsset,
        'gridRows': gridRows,
        'gridCols': gridCols,
      };
}
