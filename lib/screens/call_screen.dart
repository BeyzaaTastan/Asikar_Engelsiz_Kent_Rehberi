import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/agora_token_service.dart';

class CallScreen extends StatefulWidget {
  final bool isVolunteer;
  final String callId;
  const CallScreen({super.key, required this.isVolunteer, required this.callId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int? _remoteUid; // Karşı tarafın ID'si
  bool _localUserJoined = false; // Biz bağlandık mı?
  late RtcEngine _engine; // Agora Motoru
  StreamSubscription<DocumentSnapshot>? _cagriAboneligi;
  bool _isPopping = false;
  bool _isVideoMuted = false;
  bool _isTokenLoading = true; // Token alınıyor mu?
  bool _isTokenError = false;  // Token alınamadı mı?

  @override
  void initState() {
    super.initState();
    _isVideoMuted = widget.isVolunteer; // Gönüllü ise kamerası kapalı başlar
    initAgora();
    _cagriyiDinle();
  }

  void _cagriyiDinle() {
    _cagriAboneligi = FirebaseFirestore.instance
        .collection('cagrilar')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _cagriyiKapat();
      } else {
        var data = snapshot.data();
        if (data != null && data['cagri_durumu'] == 'bitti') {
          _cagriyiKapat();
        }
      }
    });
  }

  void _cagriyiKapat() {
    if (_isPopping) return;
    _isPopping = true;

    // Firebase'de çağrıyı bitir
    FirebaseFirestore.instance.collection('cagrilar').doc(widget.callId).update({
      'cagri_durumu': 'bitti',
    }).catchError((_) {});

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // --- 🧠 AGORA MOTORUNU ÇALIŞTIRMA ---
  Future<void> initAgora() async {
    // 1. Kullanıcıdan Kamera ve Mikrofon İzni İste
    await [Permission.microphone, Permission.camera].request();

    // 2. Sunucudan güvenli Agora token'ı al
    final String? agoraToken = await AgoraTokenService.fetchToken(
      channelName: widget.callId,
      uid: 0,
    );

    if (agoraToken == null) {
      // Token alınamazsa kullanıcıya hata göster, aramayı başlatma
      if (mounted) {
        setState(() {
          _isTokenLoading = false;
          _isTokenError = true;
        });
      }
      return;
    }

    setState(() => _isTokenLoading = false);

    final String appId = dotenv.env['AGORA_APP_ID'] ?? "";

    // 3. Motoru Oluştur ve Kimliğimizi (App ID) Tanıt
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // 4. Olayları Dinle (Biri geldi mi, biri gitti mi?)
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Odaya başarıyla katıldık");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Karşı taraf odaya katıldı: $remoteUid");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint("Karşı taraf odadan ayrıldı");
          setState(() {
            _remoteUid = null;
          });
          _cagriyiKapat();
        },
      ),
    );

    // 5. Videoyu Etkinleştir ve Odaya Katıl
    await _engine.enableVideo();
    await _engine.startPreview();

    if (widget.isVolunteer) {
      await _engine.muteLocalVideoStream(true);
    } else {
      // Arka kameraya geç (engelli birey çevresi görülsün diye)
      await _engine.switchCamera();
    }

    // 6. Güvenli token ile kanala katıl
    await _engine.joinChannel(
      token: agoraToken,
      channelId: widget.callId,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  // Sayfa kapanınca motoru durdur
  @override
  void dispose() {
    _cagriAboneligi?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  // --- 🎨 EKRAN TASARIMI ---
  @override
  Widget build(BuildContext context) {
    // Token yüklenirken yükleme ekranı göster
    if (_isTokenLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Güvenli bağlantı kuruluyor...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Token alınamazsa hata ekranı göster
    if (_isTokenError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Bağlantı kurulamadı.',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'İnternet bağlantınızı kontrol edin\nve tekrar deneyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. KATMAN: Karşı Tarafın Kamerası (Tam Ekran)
            Center(child: _remoteVideo()),

            // 2. KATMAN: Kendi Kameramız (Sağ Üstte Küçük Kare)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 120,
                height: 160,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _localUserJoined
                      ? (_isVideoMuted
                          ? Container(
                              color: Colors.grey.shade900,
                              child: const Center(
                                child: Icon(Icons.videocam_off, color: Colors.white, size: 40),
                              ),
                            )
                          : AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            ))
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
            ),

            // 3. KATMAN: Butonlar
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Kamerayı Döndür Butonu
                    Semantics(
                      button: true,
                      label: "Kamerayı Çevir",
                      child: FloatingActionButton(
                        heroTag: "switch_camera_btn",
                        onPressed: () {
                          _engine.switchCamera();
                        },
                        backgroundColor: Colors.orange.shade600,
                        child: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Kamerayı Kapat/Aç Butonu
                    Semantics(
                      button: true,
                      label: _isVideoMuted ? "Kamerayı Aç" : "Kamerayı Kapat",
                      child: FloatingActionButton(
                        heroTag: "camera_btn",
                        onPressed: () {
                          setState(() {
                            _isVideoMuted = !_isVideoMuted;
                          });
                          _engine.muteLocalVideoStream(_isVideoMuted);
                        },
                        backgroundColor: _isVideoMuted ? Colors.grey.shade800 : Colors.blue.shade600,
                        child: Icon(
                          _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Kapatma Butonu
                    Semantics(
                      button: true,
                      label: "Aramayı Sonlandır",
                      child: FloatingActionButton(
                        heroTag: "end_call_btn",
                        onPressed: () {
                          _cagriyiKapat(); // Sayfayı kapat ve Firebase'i güncelle
                        },
                        backgroundColor: Colors.red,
                        child: const Icon(
                          Icons.call_end,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Karşı tarafı gösteren widget
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.callId),
        ),
      );
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 24),
          Text(
            'Gönüllü Bekleniyor...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }
}
