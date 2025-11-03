import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiClient {
  // Spring Boot 서버 연결
  // 개발: localhost, 배포: AWS EC2 서버 URL
  static String get baseUrl {
    final currentHost = Uri.base.host;
    final currentPort = Uri.base.port;
    
    // 현재 브라우저 URL이 localhost인지 확인
    if (currentHost.contains('localhost') || 
        currentHost.contains('127.0.0.1') || 
        currentHost.isEmpty) {
      return 'http://localhost:9000';  // 로컬 개발
    } else {
      return 'https://bomiora.net:9000';  // 실제 서버
    }
  }
  
  // GET 요청
  static Future<http.Response> get(String endpoint, {Map<String, String>? additionalHeaders}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Flutter-App/1.0',
    };
    
    // 추가 헤더가 있으면 병합
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    final url = '$baseUrl$endpoint';
    print('🌐 API 요청: $url');
    print('📋 헤더: $headers');
    
    return await http.get(
      Uri.parse(url),
      headers: headers,
    );
  }
  
  // POST 요청
  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Flutter-App/1.0',
      },
      body: json.encode(data),
    );
  }
  
  // PUT 요청
  static Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Flutter-App/1.0',
      },
      body: json.encode(data),
    );
  }
  
  // DELETE 요청
  static Future<http.Response> delete(String endpoint) async {
    return await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Flutter-App/1.0',
      },
    );
  }

  // 파일 업로드 요청 (웹 호환성 고려)
  static Future<http.Response> uploadFile(String endpoint, dynamic file) async {
    try {
      print('🔍 [DEBUG] 파일 업로드 요청 시작');
      print('🌐 [DEBUG] 엔드포인트: $baseUrl$endpoint');
      print('📁 [DEBUG] 파일 타입: ${file.runtimeType}');
      print('🌍 [DEBUG] 웹 환경: $kIsWeb');
      
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      
      if (kIsWeb) {
        // 웹에서는 XFile을 직접 사용
        if (file is XFile) {
          // XFile에서 바이트 읽기
          final bytes = await file.readAsBytes();
          print('📊 [DEBUG] 웹 파일 크기: ${bytes.length} bytes');
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'image.jpg',
          ));
        } else {
          print('❌ [DEBUG] 웹에서 잘못된 파일 타입: ${file.runtimeType}');
          return http.Response('Invalid file type for web upload', 400);
        }
      } else {
        // 모바일/데스크톱에서는 파일 경로 사용
        File fileObj = file as File;
        print('📂 [DEBUG] 모바일 파일 경로: ${fileObj.path}');
        print('📊 [DEBUG] 파일 존재 여부: ${await fileObj.exists()}');
        if (await fileObj.exists()) {
          print('📊 [DEBUG] 파일 크기: ${await fileObj.length()} bytes');
        }
        request.files.add(await http.MultipartFile.fromPath('file', fileObj.path));
      }
      
      print('📤 [DEBUG] 요청 전송 중...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print('📡 [DEBUG] 업로드 응답: ${response.statusCode}');
      print('📄 [DEBUG] 응답 본문: ${response.body}');
      
      return response;
    } catch (e) {
      print('💥 [DEBUG] 파일 업로드 오류: $e');
      return http.Response('File upload failed: $e', 500);
    }
  }
}