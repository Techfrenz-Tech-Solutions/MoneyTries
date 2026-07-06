/// Generic API response wrapper used across the app.
/// Supports both backend formats:
///   New: { "success": true,  "message": "...", "data": {...} }
///   Old: { "status": 1,     "message": "...", "data": {...} }
class ApiResponse {
  final int status;
  final String message;
  final dynamic data;
  final Map<String, dynamic>? raw;

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
    this.raw,
  });

  bool get isSuccess => status == 1;

  factory ApiResponse.fromJson(Map<String, dynamic> body) {
    int statusInt;
    if (body.containsKey('success')) {
      statusInt = body['success'] == true ? 1 : 0;
    } else {
      statusInt = body['status'] is int
          ? body['status'] as int
          : int.tryParse(body['status']?.toString() ?? '0') ?? 0;
    }

    return ApiResponse(
      status: statusInt,
      message: body['message']?.toString() ?? '',
      data: body['data'],
      raw: body,
    );
  }
}
