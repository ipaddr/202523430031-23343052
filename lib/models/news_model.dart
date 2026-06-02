class NewsModel {
  final String title;
  final String image;
  final String description;
  final String source;
  final String url;
  final String publishedAt;

  const NewsModel({
    required this.title,
    required this.image,
    required this.description,
    required this.source,
    required this.url,
    required this.publishedAt,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    // Penanganan khusus untuk mem-parsing dari schema GNews API
    final Map<String, dynamic>? sourceMap = json['source'] as Map<String, dynamic>?;
    final String sourceName = sourceMap?['name']?.toString() ?? json['source']?.toString() ?? 'GameZone';

    return NewsModel(
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString() ?? json['urlToImage']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      source: sourceName,
      url: json['url']?.toString() ?? '',
      publishedAt: json['publishedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'image': image,
      'description': description,
      'source': source,
      'url': url,
      'publishedAt': publishedAt,
    };
  }
}
