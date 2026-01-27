import 'package:anderson_crm_flutter/services/dbHandler_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../services/postgresService.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();

  String _mobile = '';
  bool _remember = false;
  bool _dialog = false;
  bool _loading = false;
  bool _loading1 = false;
  String _otp = '';
  String _errorMsg = '';
  bool _showError = false;
  List<Map<String, dynamic>> _formattedRoles = [];
  bool _shouldShowSelect = false;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadRememberedMobile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mobileFocusNode.requestFocus();
      }
    });
  }

  // Safe setState wrapper
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _loadRememberedMobile() async {
    // Use the storage service instead of Util
    final storage = ref.read(storageServiceProvider);
    String logMobile = storage.getFromLocalStorage("LOGGED_IN_MOBILE");

    if (logMobile.isNotEmpty && mounted) {
      _safeSetState(() {
        _mobile = logMobile;
        _mobileController.text = logMobile;
        _remember = true;
      });
    }
  }

  void _clearMsg() {
    _safeSetState(() {
      _showError = false;
      _errorMsg = "";
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchRoles() async {
    List<Map<String, dynamic>> roles = await _getFinalRoles();
    List<Map<String, dynamic>> formattedRoles = roles.map((role) {
      return {'id': role['id'], 'name': role['name']};
    }).toList();

    _safeSetState(() {
      _formattedRoles = formattedRoles;
    });

    debugPrint("formatted roles: $formattedRoles");
    return formattedRoles;
  }

  // Future<List<Map<String, dynamic>>> _getFinalRoles() async {
  //   try {
  //     String roleIdsStr = Util.getFromSession(ref, "final_role");
  //     debugPrint("Role IDs: $roleIdsStr");
  //     List<Map<String, dynamic>> roles = [];

  //     if (roleIdsStr.isEmpty) {
  //       debugPrint("No role IDs found in session.");
  //       return roles;
  //     }

  //     List<String> roleIds = roleIdsStr.split(',');
  //     for (String roleId in roleIds) {
  //       List<dynamic> roleName = await PostgresDB().getRoleName(ref, roleId);
  //       if (roleName.isNotEmpty) {
  //         String roleNames = roleName[0]['role_name'];
  //         debugPrint("Role Name for ID $roleId: $roleNames");
  //         roles.add({'id': roleId, 'name': roleNames});
  //       }
  //     }
  //     return roles;
  //   } catch (error) {
  //     debugPrint("Error fetching roles: $error");
  //     return [];
  //   }
  // }

  Future<List<Map<String, dynamic>>> _getFinalRoles() async {
    final dbServie = ref.read(postgresServiceProvider);

    try {
      final storage = ref.read(storageServiceProvider);
      String roleIdsStr = storage.getFromSession("final_role");
      debugPrint("Role IDs: $roleIdsStr");
      List<Map<String, dynamic>> roles = [];

      if (roleIdsStr.isEmpty) {
        debugPrint("No role IDs found in session.");
        return roles;
      }

      List<String> roleIds = roleIdsStr.split(',');
      for (String roleId in roleIds) {
        // You'll need to update PostgresDB similarly
        List<dynamic> roleName = await dbServie.getRoleName(roleId);
        if (roleName.isNotEmpty) {
          String roleNames = roleName[0]['role_name'];
          debugPrint("Role Name for ID $roleId: $roleNames");
          roles.add({'id': roleId, 'name': roleNames});
        }
      }
      return roles;
    } catch (error) {
      debugPrint("Error fetching roles: $error");
      return [];
    }
  }

  // Future<void> _handleRoleSelection() async {
  //   final dbServie = ref.read(databaseServiceProvider);
  //   try {
  //     final storage = ref.read(storageServiceProvider);
  //     String finalRolesStr = storage.getFromSession("final_role");
  //     await _fetchRoles();

  //     if (finalRolesStr.isNotEmpty) {
  //       List<String> finalRoles = finalRolesStr.split(',');

  //       if (finalRoles.length > 1) {
  //         _safeSetState(() {
  //           _shouldShowSelect = true;
  //         });
  //       } else if (finalRoles.length == 1) {
  //         _safeSetState(() {
  //           _shouldShowSelect = false;
  //         });

  //         await storage.setSession("role_id", finalRoles[0]);
  //         List<dynamic> roleNameData =
  //             await dbServie.getRoleName(finalRoles[0]);
  //         await storage.setSession("role_name", roleNameData[0]['role_name']);

  //         if (mounted) {
  //           context.go('/dashboard');
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("Error in handleRoleSelection: $e");
  //     _safeSetState(() {
  //       _errorMsg = "Role selection failed: ${e.toString()}";
  //       _showError = true;
  //     });
  //     Future.delayed(const Duration(seconds: 3), _clearMsg);
  //   }
  // }

  // Future<void> _handleRoleSelection() async {
  //   try {
  //     final storage = ref.read(storageServiceProvider);
  //     String finalRolesStr = storage.getFromSession("final_role");

  //     if (finalRolesStr.isEmpty) {
  //       _safeSetState(() {
  //         _errorMsg = "No roles assigned to user";
  //         _showError = true;
  //       });
  //       return;
  //     }

  //     List<String> finalRoles = finalRolesStr.split(',');
  //     await _fetchRoles(); // Make sure this completes

  //     if (finalRoles.length > 1) {
  //       _safeSetState(() {
  //         _shouldShowSelect = true;
  //       });
  //     } else if (finalRoles.length == 1) {
  //       // Set the role data before navigation
  //       await storage.setSession("role_id", finalRoles[0]);

  //       final dbService = ref.read(databaseServiceProvider);
  //       List<dynamic> roleNameData = await dbService.getRoleName(finalRoles[0]);
  //       await storage.setSession("role_name", roleNameData[0]['role_name']);

  //       // Wait a bit before navigation
  //       await Future.delayed(Duration(milliseconds: 300));

  //       if (mounted) {
  //         context.go('/loading'); // Go to loading screen first
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("Error in handleRoleSelection: $e");
  //     _safeSetState(() {
  //       _errorMsg = "Role selection failed: ${e.toString()}";
  //       _showError = true;
  //     });
  //   }
  // }

  Future<void> _handleRoleSelection() async {
    if (!mounted) return;

    try {
      final storage = ref.read(storageServiceProvider);
      final dbService = ref.read(postgresServiceProvider);

      String finalRolesStr = storage.getFromSession("final_role");
      debugPrint("Final roles string: $finalRolesStr");

      if (finalRolesStr.isEmpty) {
        _safeSetState(() {
          _errorMsg = "No roles assigned to user";
          _showError = true;
        });
        Future.delayed(const Duration(seconds: 3), _clearMsg);
        return;
      }

      List<String> finalRoles = finalRolesStr.split(',');

      // Fetch roles data
      await _fetchRoles();

      if (finalRoles.length > 1) {
        // Multiple roles - show dropdown
        _safeSetState(() {
          _shouldShowSelect = true;
          _loading1 = false; // Stop loading indicator
        });
        debugPrint("Multiple roles found, showing dropdown");
      } else if (finalRoles.length == 1) {
        // Single role - auto-select and navigate
        debugPrint("Single role found: ${finalRoles[0]}");

        try {
          await storage.setSession("role_id", finalRoles[0]);
          List<dynamic> roleNameData =
              await dbService.getRoleName(finalRoles[0]);

          if (roleNameData.isNotEmpty) {
            await storage.setSession("role_name", roleNameData[0]['role_name']);
            debugPrint("Role set: ${roleNameData[0]['role_name']}");

            // Navigate directly to dashboard (no loading screen)
            if (mounted) {
              context.go('/dashboard');
            }
          } else {
            throw Exception("Role name not found");
          }
        } catch (e) {
          debugPrint("Error setting role: $e");
          _safeSetState(() {
            _errorMsg = "Failed to set user role";
            _showError = true;
            _loading1 = false;
          });
          Future.delayed(const Duration(seconds: 3), _clearMsg);
        }
      }
    } catch (e) {
      debugPrint("Error in handleRoleSelection: $e");
      _safeSetState(() {
        _errorMsg = "Role selection failed: ${e.toString()}";
        _showError = true;
        _loading1 = false;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
    }
  }

  Future<void> _getOtp() async {
    final dbServie = ref.read(postgresServiceProvider);
    if (_mobile.length != 10) {
      _safeSetState(() {
        _errorMsg = "Incorrect Mobile Number";
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
      return;
    }

    final result = await dbServie.login(_mobile, "");

    if (result == "200") {
      debugPrint("logged in: $result");

      // Reload caches after PostgresDB saves session data
      final storage = ref.read(storageServiceProvider);
      await storage.reloadCaches();

      String logMobile = await _getFromStorage("LOGGED_IN_MOBILE") ?? "";
      if (logMobile.isNotEmpty && _mobile == logMobile) {
        _safeSetState(() => _loading1 = true);
      }
    } else {
      debugPrint("else: $result");
      if (result.contains("Error") || result.contains("NO_MATCHES")) {
        _safeSetState(() {
          _otp = "";
          _dialog = false;
          _errorMsg = "User Not Found";
          _showError = true;
        });
        Future.delayed(const Duration(seconds: 3), _clearMsg);
        return;
      } else if (result.contains("NEW_APP")) {
        _safeSetState(() {
          _otp = "";
          _dialog = false;
          _errorMsg =
              "Please download and install the new version of this app.";
          _showError = true;
        });
        return;
      }
    }

    try {
      final data = {'mobile': _mobile};
      await Dio().post(
        "${Settings.nodeUrl}/sms/send_otp",
        data: data,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'withCredentials': 'true'},
        ),
      );
      debugPrint("OTP sent successfully");
    } catch (e) {
      _safeSetState(() {
        _errorMsg = e.toString();
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
      return;
    }

    _safeSetState(() {
      _otp = "";
      _dialog = true;
    });
  }

  // Future<void> _dummyLogin() async {
  //   final dbServie = ref.read(databaseServiceProvider);
  //   debugPrint("going to login");
  //   final result = await dbServie.login(_mobile, "");

  //   if (result == "200") {
  //     debugPrint("logged in: $result");
  //     await _handleRoleSelection();
  //   } else {
  //     debugPrint("else: $result");
  //     if (result.contains("Error") || result.contains("NO_MATCHES")) {
  //       _safeSetState(() {
  //         _otp = "";
  //         _dialog = false;
  //         _errorMsg = "User Not Found";
  //         _showError = true;
  //       });
  //       Future.delayed(const Duration(seconds: 3), _clearMsg);
  //       return;
  //     } else if (result.contains("NEW_APP")) {
  //       _safeSetState(() {
  //         _otp = "";
  //         _dialog = false;
  //         _errorMsg =
  //             "Please download and install the new version of this app.";
  //         _showError = true;
  //       });
  //       return;
  //     }
  //   }
  // }

  // Updated dropdown selection handler
  Future<void> _onRoleSelected(String roleId) async {
    if (!mounted) return;

    try {
      _safeSetState(() {
        _selectedRole = roleId;
        _loading1 = true; // Show loading while processing
      });

      final storage = ref.read(storageServiceProvider);
      final dbService = ref.read(postgresServiceProvider);

      await storage.setSession("role_id", roleId);

      List<dynamic> roleNameData = await dbService.getRoleName(roleId);
      if (roleNameData.isNotEmpty) {
        await storage.setSession("role_name", roleNameData[0]['role_name']);
        debugPrint("Selected role: ${roleNameData[0]['role_name']}");

        // Navigate directly to dashboard (no loading screen)
        if (mounted) {
          context.go('/dashboard');
        }
      } else {
        throw Exception("Role name not found");
      }
    } catch (e) {
      debugPrint("Error selecting role: $e");
      _safeSetState(() {
        _errorMsg = "Failed to select role";
        _showError = true;
        _loading1 = false;
        _selectedRole = null;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
    }
  }

// Updated _dummyLogin method
  Future<void> _dummyLogin() async {
    if (!mounted) return;

    debugPrint("going to login");
    final storage = ref.read(storageServiceProvider);
    _safeSetState(() => _loading1 = true);

    try {
      final dbService = ref.read(postgresServiceProvider);
      final result = await dbService.login(_mobile, "");

      if (result == "200") {
        debugPrint("logged in: $result");

        // Critical: Reload storage caches after PostgresDB saves session data
        // This syncs StorageService._sessionCache with the data saved by PostgresDB
        await storage.reloadCaches();

        await _handleRoleSelection();
        final empId = storage.getFromSession('logged_in_emp_id');
        final roleName = storage.getFromSession('role_name');
        final tenantId = storage.getFromSession('logged_in_tenant_id');
        debugPrint('/////////////////$empId');
        debugPrint('/////////////////$roleName');
        debugPrint('/////////////////$tenantId');
      } else {
        debugPrint("Login failed: $result");
        _safeSetState(() => _loading1 = false);

        if (result.contains("Error") || result.contains("NO_MATCHES")) {
          _safeSetState(() {
            _errorMsg = "User Not Found";
            _showError = true;
          });
        } else if (result.contains("NEW_APP")) {
          _safeSetState(() {
            _errorMsg =
                "Please download and install the new version of this app.";
            _showError = true;
          });
        } else {
          _safeSetState(() {
            _errorMsg = "Login failed: $result";
            _showError = true;
          });
        }
        Future.delayed(const Duration(seconds: 3), _clearMsg);
      }
    } catch (e) {
      debugPrint("Login error: $e");
      _safeSetState(() {
        _loading1 = false;
        _errorMsg = "Login error: ${e.toString()}";
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
    }
  }

  Future<void> _writeLog() async {
    try {
      // final box = Hive.box('login_log');
      final storage = ref.read(storageServiceProvider);
      final dbHandler = ref.read(dbHandlerProvider);

      final login = {
        '_id': 'hc:${Util.getDateForId()}_${Util.uuidv4()}',
        'date': Util.getTodayWithTime(),
        'type': Settings.type,
        'version': Settings.version,
        'emp_id': storage.getFromSession('logged_in_emp_id'),
        'emp_name': storage.getFromSession('logged_in_emp_name'),
        'mobile': storage.getFromSession('logged_in_mobile'),
        'center': storage.getFromSession('logged_in_tenant_name'),
        'department': storage.getFromSession('department_name'),
        'role_name': storage.getFromSession('role_name'),
        'region': storage.getFromSession('default_region'),
        'state': storage.getFromSession('default_state'),
        'last_updated_at': Util.getTimeStamp(),
      };

      debugPrint('>>>>>>>>>>>>>>>>>> Writing login log: $login');

      // await box.put(login['_id'], login);
      await dbHandler.putDocument(
        'login_log',
        login['_id'] ?? '',
        login,
      );

      debugPrint('Login log queued: ${login['_id']}');
    } catch (e) {
      debugPrint('Error while writing login log: $e');
    }
  }

  Future<void> _login() async {
    final dbServie = ref.read(postgresServiceProvider);
    if (_otp.length != 6) {
      _safeSetState(() {
        _errorMsg = "Incorrect OTP";
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
      return;
    }

    _safeSetState(() => _loading = true);

    try {
      final data = {
        'mobile': _mobile,
        'entered_otp': _otp,
      };

      final response = await Dio().post(
        "${Settings.nodeUrl}/sms/check_otp",
        data: data,
        options: Options(
          headers: {'withCredentials': 'true'},
        ),
      );

      if (response.data == "OTP_MATCH") {
        final result = await dbServie.login(_mobile, "");

        if (result == "200") {
          // Reload caches after PostgresDB saves session data
          final storage = ref.read(storageServiceProvider);
          await storage.reloadCaches();

          await _handleRoleSelection();
          await _writeLog();
          _safeSetState(() => _dialog = false);
        } else {
          debugPrint("else: $result");
          if (result.contains("Error")) {
            _safeSetState(() {
              _otp = "";
              _dialog = false;
              _errorMsg = "User Not Found";
              _showError = true;
            });
            Future.delayed(const Duration(seconds: 3), _clearMsg);
          } else if (result.contains("NEW_APP") ||
              result.contains("NO_MATCHES")) {
            _safeSetState(() {
              _otp = "";
              _dialog = false;
              _errorMsg =
                  "Please download and install the new version of this app.";
              _showError = true;
            });
            return;
          }
        }
      } else {
        _safeSetState(() {
          _errorMsg = "Invalid OTP";
          _showError = true;
        });
        Future.delayed(const Duration(seconds: 3), _clearMsg);
      }
    } catch (e) {
      debugPrint("error: $e");
      _safeSetState(() {
        _errorMsg = e.toString();
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 3), _clearMsg);
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  Future<String?> _getFromStorage(String item) async {
    final storage = ref.read(storageServiceProvider);
    final isMobile = await Util.isMobile();
    return isMobile
        ? storage.getFromLocalStorage(item)
        : storage.getFromSession(item);
  }

  Future<void> _rememberChange() async {
    final storage = ref.read(storageServiceProvider);
    if (_remember) {
      await storage.setLocalStorage("LOGGED_IN_MOBILE", _mobile);
    } else {
      await storage.setLocalStorage("LOGGED_IN_MOBILE", "");
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = ref.read(postgresServiceProvider);
    return Scaffold(
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              _dummyLogin();
            }
          }
        },
        child: Container(
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              if (_showError)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _errorMsg,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: MediaQuery.of(context).size.width > 600
                          ? 400
                          : MediaQuery.of(context).size.width * 0.9,
                      child: Card(
                        elevation: 4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                              child: const Text(
                                'Anderson CRM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _mobileController,
                                    focusNode: _mobileFocusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Mobile Number',
                                      prefixText: '+91 ',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    onChanged: (value) {
                                      _safeSetState(() {
                                        _mobile = value;
                                      });
                                    },
                                    onFieldSubmitted: (_) => _dummyLogin(),
                                  ),
                                  if (_shouldShowSelect) ...[
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      value: _selectedRole,
                                      hint: const Text('Select Role'),
                                      items: _formattedRoles.map((role) {
                                        return DropdownMenuItem<String>(
                                          value: role['id'],
                                          child: Text(role['name']),
                                        );
                                      }).toList(),
                                      onChanged: (value) async {
                                        if (value != null && mounted) {
                                          _safeSetState(() {
                                            _selectedRole = value;
                                          });

                                          final storage =
                                              ref.read(storageServiceProvider);
                                          await storage.setSession(
                                              "role_id", value);

                                          List<dynamic> roleNameData =
                                              await dbService
                                                  .getRoleName(value);
                                          await storage.setSession("role_name",
                                              roleNameData[0]['role_name']);

                                          if (mounted) {
                                            context.go('/dashboard');
                                          }
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Role is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _remember,
                                        onChanged: (value) {
                                          _safeSetState(() {
                                            _remember = value ?? false;
                                          });
                                          _rememberChange();
                                        },
                                      ),
                                      const Expanded(
                                        child:
                                            Text('Remember my mobile number'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading1 ? null : _getOtp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                      ),
                                      child: _loading1
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Get OTP'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOtpDialog() {
    if (!mounted) return; // Safety check

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'OTP Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                  _safeSetState(() {
                    _dialog = false;
                  });
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+91 $_mobile',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text('One time password (OTP) sent via SMS'),
              const SizedBox(height: 8),
              const Text('Enter 6 digit OTP'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (value) {
                  _safeSetState(() {
                    _otp = value;
                  });
                },
                onFieldSubmitted: (_) => _login(),
              ),
            ],
          ),
          actions: [
            const Spacer(),
            TextButton(
              onPressed: _loading ? null : _login,
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    ).then((_) {
      _safeSetState(() {
        _dialog = false;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show the dialog when _dialog is true
    if (_dialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOtpDialog();
      });
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }
}
