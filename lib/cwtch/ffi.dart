import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:io' show Platform;
import 'package:cwtch/cwtch/cwtchNotifier.dart';
import 'package:flutter/src/services/text_input.dart';
import 'package:path/path.dart' as path;

import 'package:ffi/ffi.dart';
import 'package:cwtch/cwtch/cwtch.dart';

import '../config.dart';

/////////////////////
///   Cwtch API   ///
/////////////////////

typedef start_cwtch_function = Int8 Function(Pointer<Utf8> str, Int32 length, Pointer<Utf8> str2, Int32 length2);
typedef StartCwtchFn = int Function(Pointer<Utf8> dir, int len, Pointer<Utf8> tor, int torLen);

typedef void_from_void_funtion = Void Function();
typedef VoidFromVoidFunction = void Function();

typedef void_from_string_string_function = Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32);
typedef VoidFromStringStringFn = void Function(Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef void_from_string_string_string_function = Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Int32);
typedef VoidFromStringStringStringFn = void Function(Pointer<Utf8>, int, Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef void_from_string_string_string_string_function = Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Int32);
typedef VoidFromStringStringStringStringFn = void Function(Pointer<Utf8>, int, Pointer<Utf8>, int, Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef void_from_string_string_int_int_function = Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32, Int64, Int64);
typedef VoidFromStringStringIntIntFn = void Function(Pointer<Utf8>, int, Pointer<Utf8>, int, int, int);

typedef access_cwtch_eventbus_function = Void Function();
typedef NextEventFn = void Function();

typedef string_to_void_function = Void Function(Pointer<Utf8> str, Int32 length);
typedef StringFn = void Function(Pointer<Utf8> dir, int);

typedef string_string_to_void_function = Void Function(Pointer<Utf8> str, Int32 length, Pointer<Utf8> str2, Int32 length2);
typedef StringStringFn = void Function(Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef get_json_blob_void_function = Pointer<Utf8> Function();
typedef GetJsonBlobVoidFn = Pointer<Utf8> Function();

typedef get_json_blob_string_function = Pointer<Utf8> Function(Pointer<Utf8> str, Int32 length);
typedef GetJsonBlobStringFn = Pointer<Utf8> Function(Pointer<Utf8> str, int len);

//func NumMessages(profile_ptr *C.char, profile_len C.int, handle_ptr *C.char, handle_len C.int) (n C.int) {
typedef get_int_from_str_str_function = Int32 Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32);
typedef GetIntFromStrStrFn = int Function(Pointer<Utf8>, int, Pointer<Utf8>, int);

//func GetMessage(profile_ptr *C.char, profile_len C.int, handle_ptr *C.char, handle_len C.int, message_index C.int) *C.char {
typedef get_json_blob_from_str_str_int_function = Pointer<Utf8> Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32, Int32);
typedef GetJsonBlobFromStrStrIntFn = Pointer<Utf8> Function(Pointer<Utf8>, int, Pointer<Utf8>, int, int);

// func c_GetMessagesByContentHash(profile_ptr *C.char, profile_len C.int, handle_ptr *C.char, handle_len C.int, contenthash_ptr *C.char, contenthash_len C.int) *C.char
typedef get_json_blob_from_str_str_str_function = Pointer<Utf8> Function(Pointer<Utf8>, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Int32);
typedef GetJsonBlobFromStrStrStrFn = Pointer<Utf8> Function(Pointer<Utf8>, int, Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef appbus_events_function = Pointer<Utf8> Function();
typedef AppbusEventsFn = Pointer<Utf8> Function();

class CwtchFfi implements Cwtch {
  late DynamicLibrary library;
  late CwtchNotifier cwtchNotifier;
  late Isolate cwtchIsolate;
  ReceivePort _receivePort = ReceivePort();

  CwtchFfi(CwtchNotifier _cwtchNotifier) {
    if (Platform.isWindows) {
      library = DynamicLibrary.open("libCwtch.dll");
    } else if (Platform.isLinux) {
      library = DynamicLibrary.open("libCwtch.so");
    } else if (Platform.isIOS) {
      library = DynamicLibrary.process();
    } else {
      print("OS ${Platform.operatingSystem} not supported by cwtch/ffi");
      // emergency, ideally the app stays on splash and just posts the error till user closes
      exit(0);
    }
    cwtchNotifier = _cwtchNotifier;
  }

  // ignore: non_constant_identifier_names
  Future<void> Start() async {
    String home = "";
    String bundledTor = "";
    Map<String, String> envVars = Platform.environment;
    if (Platform.isLinux) {
      home = envVars['HOME']!;
      if (await File("linux/tor").exists()) {
        bundledTor = "linux/tor";
      } else if (await File("lib/tor").exists()) {
        bundledTor = "lib/tor";
      } else if (await File(path.join(home, ".local/lib/cwtch/tor")).exists()) {
        bundledTor = path.join(home, ".local/lib/cwtch/tor");
      } else if (await File("/usr/lib/cwtch/tor").exists()) {
        bundledTor = "/usr/lib/cwtch/tor";
      } else {
        bundledTor = "tor";
      }
    } else if (Platform.isWindows) {
      home = envVars['UserProfile']!;
      bundledTor = "Tor\\Tor\\tor.exe";
    }

    var cwtchDir = envVars['CWTCH_HOME'] ?? path.join(home, ".cwtch");
    if (EnvironmentConfig.BUILD_VER == dev_version) {
      cwtchDir = path.join(cwtchDir, "dev");
    }
    print("StartCwtch( cwtchdir: $cwtchDir, torPath: $bundledTor )");

    var startCwtchC = library.lookup<NativeFunction<start_cwtch_function>>("c_StartCwtch");
    // ignore: non_constant_identifier_names
    final StartCwtch = startCwtchC.asFunction<StartCwtchFn>();

    final ut8CwtchDir = cwtchDir.toNativeUtf8();
    StartCwtch(ut8CwtchDir, ut8CwtchDir.length, bundledTor.toNativeUtf8(), bundledTor.length);

    // Spawn an isolate to listen to events from libcwtch-go and then dispatch them when received on main thread to cwtchNotifier
    cwtchIsolate = await Isolate.spawn(_checkAppbusEvents, _receivePort.sendPort);
    _receivePort.listen((message) {
      var env = jsonDecode(message);
      cwtchNotifier.handleMessage(env["EventType"], env["Data"]);
    });
  }

  // ignore: non_constant_identifier_names
  Future<void> ReconnectCwtchForeground() async {
    var reconnectCwtch = library.lookup<NativeFunction<Void Function()>>("c_ReconnectCwtchForeground");
    // ignore: non_constant_identifier_names
    final ReconnectCwtchForeground = reconnectCwtch.asFunction<void Function()>();
    ReconnectCwtchForeground();
  }

  // Called on object being disposed to (presumably on app close) to close the isolate that's listening to libcwtch-go events
  @override
  void dispose() {
    if (cwtchIsolate != null) {
      cwtchIsolate.kill(priority: Isolate.immediate);
    }
  }

  // Entry point for an isolate to listen to a stream of events pulled from libcwtch-go and return them on the sendPort
  static void _checkAppbusEvents(SendPort sendPort) async {
    var stream = pollAppbusEvents();
    await for (var value in stream) {
      sendPort.send(value);
    }
    print("checkAppBusEvents finished...");
  }

  // Steam of appbus events. Call blocks in libcwtch-go GetAppbusEvent.  Static so the isolate can use it
  static Stream<String> pollAppbusEvents() async* {
    late DynamicLibrary library;
    if (Platform.isWindows) {
      library = DynamicLibrary.open("libCwtch.dll");
    } else if (Platform.isLinux) {
      library = DynamicLibrary.open("libCwtch.so");
    }

    var getAppbusEventC = library.lookup<NativeFunction<appbus_events_function>>("c_GetAppBusEvent");
    // ignore: non_constant_identifier_names
    final GetAppbusEvent = getAppbusEventC.asFunction<AppbusEventsFn>();

    while (true) {
      Pointer<Utf8> result = GetAppbusEvent();
      String event = result.toDartString();

      if (event.startsWith("{\"EventType\":\"Shutdown\"")) {
        print("Shutting down isolate thread: $event");
        return;
      }
      yield event;
    }
  }

  // ignore: non_constant_identifier_names
  void SelectProfile(String onion) async {
    var selectProfileC = library.lookup<NativeFunction<get_json_blob_string_function>>("c_SelectProfile");
    // ignore: non_constant_identifier_names
    final SelectProfile = selectProfileC.asFunction<GetJsonBlobStringFn>();
    final ut8Onion = onion.toNativeUtf8();
    SelectProfile(ut8Onion, ut8Onion.length);
  }

  // ignore: non_constant_identifier_names
  void CreateProfile(String nick, String pass) {
    var createProfileC = library.lookup<NativeFunction<void_from_string_string_function>>("c_CreateProfile");
    // ignore: non_constant_identifier_names
    final CreateProfile = createProfileC.asFunction<VoidFromStringStringFn>();
    final utf8nick = nick.toNativeUtf8();
    final ut8pass = pass.toNativeUtf8();
    CreateProfile(utf8nick, utf8nick.length, ut8pass, ut8pass.length);
  }

  // ignore: non_constant_identifier_names
  void LoadProfiles(String pass) {
    var loadProfileC = library.lookup<NativeFunction<string_to_void_function>>("c_LoadProfiles");
    // ignore: non_constant_identifier_names
    final LoadProfiles = loadProfileC.asFunction<StringFn>();
    final ut8pass = pass.toNativeUtf8();
    LoadProfiles(ut8pass, ut8pass.length);
  }

  // ignore: non_constant_identifier_names
  Future<String> GetMessage(String profile, String handle, int index) async {
    var getMessageC = library.lookup<NativeFunction<get_json_blob_from_str_str_int_function>>("c_GetMessage");
    // ignore: non_constant_identifier_names
    final GetMessage = getMessageC.asFunction<GetJsonBlobFromStrStrIntFn>();
    final utf8profile = profile.toNativeUtf8();
    final utf8handle = handle.toNativeUtf8();
    Pointer<Utf8> jsonMessageBytes = GetMessage(utf8profile, utf8profile.length, utf8handle, utf8handle.length, index);
    String jsonMessage = jsonMessageBytes.toDartString();
    return jsonMessage;
  }

  @override
  // ignore: non_constant_identifier_names
  void SendProfileEvent(String onion, String json) {
    var sendAppBusEvent = library.lookup<NativeFunction<string_string_to_void_function>>("c_SendProfileEvent");
    // ignore: non_constant_identifier_names
    final SendAppBusEvent = sendAppBusEvent.asFunction<StringStringFn>();
    final utf8onion = onion.toNativeUtf8();
    final utf8json = json.toNativeUtf8();
    SendAppBusEvent(utf8onion, utf8onion.length, utf8json, utf8json.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void SendAppEvent(String json) {
    var sendAppBusEvent = library.lookup<NativeFunction<string_to_void_function>>("c_SendAppEvent");
    // ignore: non_constant_identifier_names
    final SendAppBusEvent = sendAppBusEvent.asFunction<StringFn>();
    final utf8json = json.toNativeUtf8();
    SendAppBusEvent(utf8json, utf8json.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void AcceptContact(String profileOnion, String contactHandle) {
    var acceptContact = library.lookup<NativeFunction<string_string_to_void_function>>("c_AcceptContact");
    // ignore: non_constant_identifier_names
    final AcceptContact = acceptContact.asFunction<VoidFromStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = contactHandle.toNativeUtf8();
    AcceptContact(u1, u1.length, u2, u2.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void BlockContact(String profileOnion, String contactHandle) {
    var blockContact = library.lookup<NativeFunction<string_string_to_void_function>>("c_BlockContact");
    // ignore: non_constant_identifier_names
    final BlockContact = blockContact.asFunction<VoidFromStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = contactHandle.toNativeUtf8();
    BlockContact(u1, u1.length, u2, u2.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void SendMessage(String profileOnion, String contactHandle, String message) {
    var sendMessage = library.lookup<NativeFunction<void_from_string_string_string_function>>("c_SendMessage");
    // ignore: non_constant_identifier_names
    final SendMessage = sendMessage.asFunction<VoidFromStringStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = contactHandle.toNativeUtf8();
    final u3 = message.toNativeUtf8();
    SendMessage(u1, u1.length, u2, u2.length, u3, u3.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void SendInvitation(String profileOnion, String contactHandle, String target) {
    var sendInvitation = library.lookup<NativeFunction<void_from_string_string_string_function>>("c_SendInvitation");
    // ignore: non_constant_identifier_names
    final SendInvitation = sendInvitation.asFunction<VoidFromStringStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = contactHandle.toNativeUtf8();
    final u3 = target.toNativeUtf8();
    SendInvitation(u1, u1.length, u2, u2.length, u3, u3.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void ResetTor() {
    var resetTor = library.lookup<NativeFunction<Void Function()>>("c_ResetTor");
    // ignore: non_constant_identifier_names
    final ResetTor = resetTor.asFunction<void Function()>();
    ResetTor();
  }

  @override
  // ignore: non_constant_identifier_names
  void ImportBundle(String profileOnion, String bundle) {
    var importBundle = library.lookup<NativeFunction<string_string_to_void_function>>("c_ImportBundle");
    // ignore: non_constant_identifier_names
    final ImportBundle = importBundle.asFunction<VoidFromStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = bundle.toNativeUtf8();
    ImportBundle(u1, u1.length, u2, u2.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void SetGroupAttribute(String profileOnion, String groupHandle, String key, String value) {
    var setGroupAttribute = library.lookup<NativeFunction<void_from_string_string_string_string_function>>("c_SetGroupAttribute");
    // ignore: non_constant_identifier_names
    final SetGroupAttribute = setGroupAttribute.asFunction<VoidFromStringStringStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = groupHandle.toNativeUtf8();
    final u3 = key.toNativeUtf8();
    final u4 = value.toNativeUtf8();
    SetGroupAttribute(u1, u1.length, u2, u2.length, u3, u3.length, u4, u4.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void RejectInvite(String profileOnion, String groupHandle) {
    var rejectInvite = library.lookup<NativeFunction<string_string_to_void_function>>("c_RejectInvite");
    // ignore: non_constant_identifier_names
    final RejectInvite = rejectInvite.asFunction<VoidFromStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = groupHandle.toNativeUtf8();
    RejectInvite(u1, u1.length, u2, u2.length);
  }

  @override
  void CreateGroup(String profileOnion, String server, String groupName) {
    var createGroup = library.lookup<NativeFunction<void_from_string_string_string_function>>("c_CreateGroup");
    // ignore: non_constant_identifier_names
    final CreateGroup = createGroup.asFunction<VoidFromStringStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = server.toNativeUtf8();
    final u3 = groupName.toNativeUtf8();
    CreateGroup(u1, u1.length, u2, u2.length, u3, u3.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void LeaveConversation(String profileOnion, String handle) {
    var leaveConversation = library.lookup<NativeFunction<string_string_to_void_function>>("c_LeaveConversation");
    // ignore: non_constant_identifier_names
    final LeaveConversation = leaveConversation.asFunction<VoidFromStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = handle.toNativeUtf8();
    LeaveConversation(u1, u1.length, u2, u2.length);
  }

  @override
  // ignore: non_constant_identifier_names
  void LeaveGroup(String profileOnion, String groupHandle) {
    var leaveGroup = library.lookup<NativeFunction<string_string_to_void_function>>("c_LeaveGroup");
    // ignore: non_constant_identifier_names
    final LeaveGroup = leaveGroup.asFunction<VoidFromStringStringFn>();
    final u1 = profileOnion.toNativeUtf8();
    final u2 = groupHandle.toNativeUtf8();
    LeaveGroup(u1, u1.length, u2, u2.length);
  }

  @override
  void UpdateMessageFlags(String profile, String handle, int index, int flags) {
    var updateMessageFlagsC = library.lookup<NativeFunction<void_from_string_string_int_int_function>>("c_UpdateMessageFlags");
    // ignore: non_constant_identifier_names
    final updateMessageFlags = updateMessageFlagsC.asFunction<VoidFromStringStringIntIntFn>();
    final utf8profile = profile.toNativeUtf8();
    final utf8handle = handle.toNativeUtf8();
    updateMessageFlags(utf8profile, utf8profile.length, utf8handle, utf8handle.length, index, flags);
  }

  @override
  // ignore: non_constant_identifier_names
  void DeleteProfile(String onion, String currentPassword) {
    var deleteprofile = library.lookup<NativeFunction<string_string_to_void_function>>("c_DeleteProfile");
    // ignore: non_constant_identifier_names
    final DeleteProfile = deleteprofile.asFunction<VoidFromStringStringFn>();
    final u1 = onion.toNativeUtf8();
    final u2 = currentPassword.toNativeUtf8();
    DeleteProfile(u1, u1.length, u2, u2.length);
  }

  @override
  Future<void> Shutdown() async {
    var shutdown = library.lookup<NativeFunction<void_from_void_funtion>>("c_ShutdownCwtch");
    // ignore: non_constant_identifier_names

    // Shutdown Cwtch + Tor...
    final Shutdown = shutdown.asFunction<VoidFromVoidFunction>();
    Shutdown();

    // Kill our Isolate
    cwtchIsolate.kill(priority: Isolate.immediate);
    print("Isolate killed");

    _receivePort.close();
    print("Receive Port Closed");
  }

  @override
  Future GetMessageByContentHash(String profile, String handle, String contentHash) async {
    var getMessagesByContentHashC = library.lookup<NativeFunction<get_json_blob_from_str_str_str_function>>("c_GetMessagesByContentHash");
    // ignore: non_constant_identifier_names
    final GetMessagesByContentHash = getMessagesByContentHashC.asFunction<GetJsonBlobFromStrStrStrFn>();
    final utf8profile = profile.toNativeUtf8();
    final utf8handle = handle.toNativeUtf8();
    final utf8contentHash = contentHash.toNativeUtf8();
    Pointer<Utf8> jsonMessageBytes = GetMessagesByContentHash(utf8profile, utf8profile.length, utf8handle, utf8handle.length, utf8contentHash, utf8contentHash.length);
    String jsonMessage = jsonMessageBytes.toDartString();
    return jsonMessage;
  }
}
