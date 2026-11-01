import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:xml2json/xml2json.dart';

typedef BookRepositoryData = ({CategoryFeed? feed, HttpFailure? failure});

abstract class BookRepository {
  final Dio httpClient;

  const BookRepository(this.httpClient);

  Future<BookRepositoryData> getCategory(String url) async {
    final requestUri = Uri.parse(url).hasScheme
        ? Uri.parse(url)
        : Uri.parse(httpClient.options.baseUrl).resolve(url);
    try {
      final res = await httpClient.get(url);
      final statusCode = res.statusCode;
      if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
        if (statusCode == 404) {
          return (feed: null, failure: HttpFailure.notFound);
        }

        final isCloudflareChallenge =
            res.headers.value('cf-mitigated') == 'challenge' ||
                res.data.toString().contains('Just a moment...');
        final reason =
            isCloudflareChallenge ? ' (Cloudflare security challenge)' : '';
        return (
          feed: null,
          failure: HttpFailure(
            'Book feed request to $requestUri failed with HTTP '
            '$statusCode$reason.',
          ),
        );
      }

      CategoryFeed category;
      final Xml2Json xml2json = Xml2Json();
      xml2json.parse(res.data.toString());
      final json = jsonDecode(xml2json.toGData());
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected an object in the feed response.');
      }
      category = CategoryFeed.fromJson(json);
      return (feed: category, failure: null);
    } on Xml2JsonException catch (error, stackTrace) {
      return _invalidResponse(requestUri, error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      return _invalidResponse(requestUri, error, stackTrace);
    } on DioException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Book feed request failed for $requestUri: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      final statusCode = error.response?.statusCode;
      if (statusCode == 404) {
        return (feed: null, failure: HttpFailure.notFound);
      }

      final message = statusCode == null
          ? 'Unable to access book feed at $requestUri: '
              '${error.message ?? error.type.name}. Check the network and '
              'browser CORS policy.'
          : 'Book feed request to $requestUri failed with HTTP $statusCode.';
      return (feed: null, failure: HttpFailure(message));
    }
  }

  BookRepositoryData _invalidResponse(
    Uri requestUri,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint('Invalid book feed response from $requestUri: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return (
      feed: null,
      failure: HttpFailure(
        'Invalid book feed response from $requestUri: $error',
      ),
    );
  }
}
