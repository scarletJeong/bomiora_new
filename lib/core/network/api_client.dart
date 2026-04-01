import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiClient {
  // Spring Boot 서버 연결
  // 개발: localhost (웹) 또는 PC IP (모바일), 배포: AWS EC2 서버 URL
  
  // 개발 서버 설정
  // 옵션 1: 도메인 사용 (HTTPS)
  static const String _devServerUrl = 'https://bomiora.net';
  // 옵션 2: IP 주소 사용 (HTTP) - IP로 접근 시 HTTP가 되는 경우
  // static const String _devServerUrl = 'http://3.128.180.207:9000';
  
  // PC의 로컬 IP 주소 (로컬 개발 시 사용)
  // 네트워크가 변경되면 이 값을 업데이트해야 합니다
  // Windows에서 확인: ipconfig 명령어로 IPv4 주소 확인
  static const String _localPcIp = '172.30.1.83';  // PC의 실제 IP 주소
  
  static String get baseUrl {
    if (kIsWeb) {
      // 웹 환경: 브라우저의 현재 URL 확인
      final currentHost = Uri.base.host;
      final currentPort = Uri.base.port;
      
      // 현재 브라우저 URL이 localhost인지 확인
      if (currentHost.contains('localhost') || 
          currentHost.contains('127.0.0.1') || 
          currentHost.isEmpty) {
        return 'http://localhost:9000';  // 웹 로컬 개발
      } else {
        return _devServerUrl;  // 개발 서버
      }
    } else {
      // 모바일/데스크톱 환경: 개발 서버 사용 (로컬 IP 연결 문제 해결)
      // 로컬 개발이 필요하면 아래 주석을 해제하고 _devServerUrl 대신 사용
      // return 'http://$_localPcIp:9000';  // 로컬 서버 사용
      return _devServerUrl;  // 개발 서버 사용
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
    
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
  }
  
  // POST 요청
  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final url = '$baseUrl$endpoint';
    
    // 브라우저와 동일한 헤더 설정 (405 오류 방지)
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // User-Agent를 브라우저와 유사하게 설정 (서버가 특정 User-Agent만 허용할 수 있음)
      if (!kIsWeb) 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    
    final body = json.encode(data);
    
    print('📤 [API POST] URL: $url');
    print('📤 [API POST] Headers: $headers');
    print('📤 [API POST] Body: ${data.toString().replaceAll(RegExp(r'password[:\s]*[^,}]+'), 'password: [보호됨]')}');
    
    try {
      print('⏳ [API POST] 요청 시작...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ [API POST] 타임아웃 발생 (30초)');
          throw TimeoutException('요청 시간이 초과되었습니다', const Duration(seconds: 30));
        },
      );
      
      print('✅ [API POST] 응답 수신 완료');
      print('📥 [API POST] 응답 상태: ${response.statusCode}');
      print('📥 [API POST] 응답 헤더: ${response.headers}');
      print('📥 [API POST] 응답 본문 길이: ${response.body.length} bytes');
      if (response.body.length < 500) {
        print('📥 [API POST] 응답 본문: ${response.body}');
      }
      
      return response;
    } on TimeoutException catch (e) {
      print('⏱️ [API POST] 타임아웃 오류: $e');
      rethrow;
    } on SocketException catch (e) {
      print('🌐 [API POST] 네트워크 연결 오류: $e');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ [API POST] 요청 실패: $e');
      print('❌ [API POST] 스택 트레이스: $stackTrace');
      rethrow;
    }
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
  static Future<http.Response> delete(String endpoint, {Map<String, dynamic>? data}) async {
    return await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Flutter-App/1.0',
      },
      body: data != null ? json.encode(data) : null,
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